#!/usr/bin/env python3
# Command OS — pantalla de inicio de sesión (greeter de greetd): ventana GTK 4 a pantalla completa
# dentro de cage, como el usuario greeter. Mismo diseño que el asistente de primer arranque, en
# castellano. La lanza command-os-greeter.
#
# La comprobación de la contraseña la hace greetd con PAM: aquí solo se habla con greetd por su
# socket ($GREETD_SOCK; mensajes JSON precedidos de su longitud en 4 bytes) y la contraseña no se
# guarda ni se registra en ningún sitio. La conversación va en un hilo aparte: PAM tarda (unos 2 s
# tras un fallo) y la ventana no debe congelarse.
import json
import os
import pwd
import socket
import struct
import subprocess
import sys
import threading
import time

from comun import CONF, cargar_tema, fila, leer, logo, panel
from gi.repository import GLib, Gtk

SESION = ["command-os-session"]
DIAS = ["lun", "mar", "mié", "jue", "vie", "sáb", "dom"]
MESES = ["ene", "feb", "mar", "abr", "may", "jun", "jul", "ago", "sep", "oct", "nov", "dic"]


def cuentas():
    """Cuentas de personas: uid entre 1000 y 60000 con un shell de verdad."""
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
        # pam_faillock bloquea la cuenta unos minutos tras varios fallos seguidos: entonces también
        # falla la contraseña buena, y PAM no lo distingue de una contraseña mal escrita.
        return ("contraseña incorrecta. tras varios intentos fallidos la cuenta se bloquea unos "
                "minutos: espera y vuelve a probar.")
    return "no se pudo entrar: " + (r.get("description") or "error desconocido") + "."


class Pantalla(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="cmd-os")
        self.personas = cuentas()
        fondo, caja = panel(420)

        self.hora = Gtk.Label(xalign=0.5)
        self.hora.add_css_class("hora")
        caja.append(self.hora)
        self.fecha = Gtk.Label(xalign=0.5)
        self.fecha.add_css_class("tenue")
        caja.append(self.fecha)
        self.reloj()
        GLib.timeout_add_seconds(5, self.reloj)

        marca = logo(36)
        if marca:
            caja.append(marca)

        nombres = [
            f"{p.pw_gecos.split(',')[0]}  ·  {p.pw_name}" if p.pw_gecos.split(",")[0] else p.pw_name
            for p in self.personas
        ]
        self.lista = Gtk.DropDown.new_from_strings(nombres or ["—"])
        principal = leer(f"{CONF}/cuenta-principal")
        for i, p in enumerate(self.personas):
            if p.pw_name == principal:
                self.lista.set_selected(i)
        caja.append(fila("cuenta", self.lista))

        self.clave = Gtk.PasswordEntry(show_peek_icon=True)
        self.clave.connect("activate", self.on_entrar)
        caja.append(fila("contraseña", self.clave))

        self.error = Gtk.Label(xalign=0, wrap=True, max_width_chars=44)
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

        self.set_child(fondo)
        self.clave.grab_focus()

    def reloj(self):
        t = time.localtime()
        self.hora.set_text(time.strftime("%H:%M", t))
        self.fecha.set_text(f"{DIAS[t.tm_wday]} {t.tm_mday} {MESES[t.tm_mon - 1]}")
        return True

    def on_entrar(self, *_):
        if not self.personas:
            self.error.set_text("no hay ninguna cuenta en este equipo.")
            return
        if not self.boton.get_sensitive():
            return  # ya hay un intento en marcha
        self.boton.set_sensitive(False)
        self.error.set_text("comprobando…")
        usuario = self.personas[self.lista.get_selected()].pw_name
        clave = self.clave.get_text()
        self.clave.set_text("")
        threading.Thread(target=self.intento, args=(usuario, clave), daemon=True).start()

    def intento(self, usuario, clave):
        try:
            fallo = entrar(usuario, clave)
        except (OSError, ValueError, KeyError, struct.error) as e:
            fallo = f"no se pudo hablar con greetd ({e})."
        GLib.idle_add(self.resultado, fallo)

    def resultado(self, fallo):
        if fallo is None:
            self.get_application().quit()
            return False
        self.error.set_text(fallo)
        self.boton.set_sensitive(True)
        self.clave.grab_focus()
        return False


class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.commandlab.Greeter")

    def do_activate(self):
        cargar_tema()
        ventana = Pantalla(self)
        ventana.fullscreen()
        ventana.present()


if __name__ == "__main__":
    App().run([])
    sys.exit(0)
