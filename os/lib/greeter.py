#!/usr/bin/env python3
# Command OS — pantalla de inicio de sesión (greeter de greetd): ventana GTK 4 a pantalla completa
# dentro de cage, como el usuario greeter. Mismo diseño que el asistente de primer arranque, en
# castellano. La lanza command-os-greeter.
#
# La comprobación de la contraseña la hace greetd con PAM: aquí solo se habla con greetd por su
# socket ($GREETD_SOCK; mensajes JSON precedidos de su longitud en 4 bytes) y la contraseña no se
# guarda ni se registra en ningún sitio.
import json
import os
import pwd
import socket
import struct
import subprocess
import sys
import time

import gi

gi.require_version("Gtk", "4.0")
from gi.repository import Gdk, GdkPixbuf, GLib, Gtk  # noqa: E402

CONF = "/etc/command-os"
CSS = "/usr/share/command-os/greeter/command.css"
LOGO = "/usr/share/command-os/logo/command-wordmark-white.png"
SESION = ["command-os-session"]
DIAS = ["lun", "mar", "mié", "jue", "vie", "sáb", "dom"]
MESES = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]


def leer(ruta, defecto=""):
    try:
        with open(ruta, encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return defecto


def cuentas():
    """Cuentas de personas: uid >= 1000 con un shell de verdad."""
    malos = ("nologin", "false")
    lista = [
        p for p in pwd.getpwall()
        if 1000 <= p.pw_uid < 60000 and not p.pw_shell.endswith(malos)
    ]
    return sorted(lista, key=lambda p: p.pw_uid)


class Greetd:
    """Cliente mínimo del protocolo IPC de greetd."""

    def __init__(self):
        self.s = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.s.connect(os.environ["GREETD_SOCK"])

    def pedir(self, mensaje):
        datos = json.dumps(mensaje).encode()
        self.s.sendall(struct.pack("=I", len(datos)) + datos)
        largo = struct.unpack("=I", self._leer(4))[0]
        return json.loads(self._leer(largo))

    def _leer(self, n):
        datos = b""
        while len(datos) < n:
            trozo = self.s.recv(n - len(datos))
            if not trozo:
                raise ConnectionError("greetd cerró la conexión")
            datos += trozo
        return datos


def entrar(usuario, contrasena):
    """Abre la sesión de Command OS. Devuelve None si todo va bien o el texto del error."""
    g = Greetd()
    r = g.pedir({"type": "create_session", "username": usuario})
    while r.get("type") == "auth_message":
        if r.get("auth_message_type") == "secret":
            r = g.pedir({"type": "post_auth_message_response", "response": contrasena})
        elif r.get("auth_message_type") in ("info", "error"):
            r = g.pedir({"type": "post_auth_message_response", "response": None})
        else:  # visible: no se usa en Command OS
            r = g.pedir({"type": "post_auth_message_response", "response": ""})
    if r.get("type") == "success":
        r = g.pedir({"type": "start_session", "cmd": SESION, "env": []})
        if r.get("type") == "success":
            return None
    g.pedir({"type": "cancel_session"})
    if r.get("error_type") == "auth_error":
        return "contraseña incorrecta."
    return "no se pudo entrar: " + (r.get("description") or "error desconocido") + "."


class Pantalla(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="cmd-os")
        self.personas = cuentas()

        caja = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        caja.add_css_class("panel")
        caja.set_halign(Gtk.Align.CENTER)
        caja.set_hexpand(True)
        caja.set_valign(Gtk.Align.CENTER)
        caja.set_size_request(420, -1)

        self.hora = Gtk.Label(xalign=0.5)
        self.hora.add_css_class("hora")
        caja.append(self.hora)
        self.fecha = Gtk.Label(xalign=0.5)
        self.fecha.add_css_class("tenue")
        caja.append(self.fecha)
        self.reloj()
        GLib.timeout_add_seconds(5, self.reloj)

        if os.path.exists(LOGO):
            # Escalado de antemano: a tamaño natural, el wordmark ensancharía todo el panel.
            imagen = GdkPixbuf.Pixbuf.new_from_file_at_scale(LOGO, 400, 36, True)
            logo = Gtk.Picture.new_for_paintable(Gdk.Texture.new_for_pixbuf(imagen))
            logo.set_content_fit(Gtk.ContentFit.SCALE_DOWN)
            logo.set_halign(Gtk.Align.CENTER)
            caja.append(logo)

        nombres = [
            f"{p.pw_gecos.split(',')[0]}  ·  {p.pw_name}" if p.pw_gecos.split(",")[0] else p.pw_name
            for p in self.personas
        ]
        self.lista = Gtk.DropDown.new_from_strings(nombres or ["—"])
        principal = leer(f"{CONF}/cuenta-principal")
        for i, p in enumerate(self.personas):
            if p.pw_name == principal:
                self.lista.set_selected(i)
        caja.append(self.fila("cuenta", self.lista))

        self.clave = Gtk.PasswordEntry(show_peek_icon=True)
        self.clave.connect("activate", self.on_entrar)
        caja.append(self.fila("contraseña", self.clave))

        self.error = Gtk.Label(xalign=0, wrap=True)
        self.error.add_css_class("error")
        caja.append(self.error)

        self.boton = Gtk.Button(label="entrar")
        self.boton.add_css_class("suggested-action")
        self.boton.connect("clicked", self.on_entrar)
        caja.append(self.boton)

        energia = Gtk.Box(spacing=8, halign=Gtk.Align.CENTER)
        for texto, orden in (("reiniciar", "reboot"), ("apagar", "poweroff")):
            b = Gtk.Button(label=texto)
            b.add_css_class("flat")
            b.connect("clicked", lambda _b, o=orden: subprocess.Popen(["systemctl", o]))
            energia.append(b)
        caja.append(energia)

        fondo = Gtk.Box(hexpand=True)
        fondo.add_css_class("fondo")
        fondo.append(caja)
        self.set_child(fondo)
        self.clave.grab_focus()

    def fila(self, etiqueta, widget):
        fila = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        texto = Gtk.Label(label=etiqueta, xalign=0)
        texto.add_css_class("etiqueta")
        fila.append(texto)
        fila.append(widget)
        return fila

    def reloj(self):
        t = time.localtime()
        self.hora.set_text(time.strftime("%H:%M", t))
        self.fecha.set_text(f"{DIAS[t.tm_wday]} {t.tm_mday} {MESES[t.tm_mon - 1]}")
        return True

    def on_entrar(self, *_):
        if not self.personas:
            self.error.set_text("no hay ninguna cuenta en este equipo.")
            return
        self.boton.set_sensitive(False)
        self.error.set_text("")
        usuario = self.personas[self.lista.get_selected()].pw_name
        clave = self.clave.get_text()
        self.clave.set_text("")
        try:
            fallo = entrar(usuario, clave)
        except (OSError, ValueError, KeyError) as e:
            fallo = f"no se pudo hablar con greetd ({e})."
        if fallo is None:
            self.get_application().quit()
            return
        self.error.set_text(fallo)
        self.boton.set_sensitive(True)
        self.clave.grab_focus()


class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.commandlab.Greeter")

    def do_activate(self):
        css = Gtk.CssProvider()
        if os.path.exists(CSS):
            css.load_from_path(CSS)
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_USER
        )
        ventana = Pantalla(self)
        ventana.fullscreen()
        ventana.present()


if __name__ == "__main__":
    App().run([])
    sys.exit(0)
