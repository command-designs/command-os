#!/usr/bin/env python3
# Command OS — asistente de primer arranque (ventana GTK 4 a pantalla completa dentro de cage, como
# root). Pide teclado, nombre, usuario y contraseña, y si se entra solo al encender; crea la cuenta
# con /usr/lib/command-os/crear-cuenta (la contraseña va por la entrada estándar, nunca en
# argumentos ni registros). Lo lanza command-os-primer-arranque.
#
# Códigos de salida: 0 cuenta creada · 3 cambio de teclado (el lanzador vuelve a abrir cage con la
# distribución nueva, para que lo que se escriba ya salga con ella).
import os
import re
import subprocess
import sys
import unicodedata

from comun import CONF, cargar_tema, fila, leer, logo, panel
from gi.repository import GLib, Gtk

CREAR = "/usr/lib/command-os/crear-cuenta"
MIN_CONTRASENA = 8

TECLADOS = [
    ("es", "español (España)"),
    ("latam", "español (Latinoamérica)"),
    ("us", "inglés (EE. UU.)"),
    ("gb", "inglés (Reino Unido)"),
    ("pt", "portugués (Portugal)"),
    ("br", "portugués (Brasil)"),
    ("fr", "francés"),
    ("de", "alemán"),
    ("it", "italiano"),
]


def usuario_desde(nombre):
    """«Daniel Infante» -> «daniel»: primera palabra, sin tildes, en minúsculas."""
    plano = unicodedata.normalize("NFKD", nombre).encode("ascii", "ignore").decode()
    palabra = (plano.lower().split() or [""])[0]
    return re.sub(r"[^a-z0-9_-]", "", palabra)[:32]


class Asistente(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app, title="cmd-os · primer arranque")
        self.usuario_tocado = False
        self.teclado = leer(f"{CONF}/kb_layout", "es")

        fondo, caja = panel(460)
        marca = logo(44)
        if marca:
            caja.append(marca)

        titulo = Gtk.Label(label="› primer arranque", xalign=0)
        titulo.add_css_class("titulo")
        caja.append(titulo)
        intro = Gtk.Label(
            label="crea la cuenta con la que vas a usar este equipo.", xalign=0, wrap=True
        )
        intro.add_css_class("tenue")
        caja.append(intro)

        # Teclado: lo primero, para que el resto ya se escriba con él.
        # Si el instalador dejó otra distribución (us-intl, de(nodeadkeys)…), sale la primera y
        # seleccionada: la lista nunca enseña un teclado distinto del que se está usando.
        self.teclados = list(TECLADOS)
        if self.teclado not in [c for c, _ in self.teclados]:
            self.teclados.insert(0, (self.teclado, f"{self.teclado} (del instalador)"))
        self.combo = Gtk.DropDown.new_from_strings([n for _, n in self.teclados])
        self.combo.set_selected([c for c, _ in self.teclados].index(self.teclado))
        self.combo.connect("notify::selected", self.on_teclado)
        caja.append(fila("teclado", self.combo))

        self.nombre = Gtk.Entry(placeholder_text="opcional")
        self.nombre.connect("changed", self.on_nombre)
        caja.append(fila("tu nombre", self.nombre))

        self.usuario = Gtk.Entry(placeholder_text="minúsculas, sin espacios")
        self.usuario.connect("changed", self.on_usuario)
        caja.append(fila("usuario", self.usuario))

        self.clave = Gtk.PasswordEntry(show_peek_icon=True)
        self.clave.set_property("placeholder-text", f"al menos {MIN_CONTRASENA} caracteres")
        caja.append(fila("contraseña", self.clave))
        self.clave2 = Gtk.PasswordEntry(show_peek_icon=True)
        self.clave2.connect("activate", self.on_crear)
        caja.append(fila("repítela", self.clave2))

        admin = Gtk.Label(
            label="esta cuenta administra el equipo: instala programas y cambia el sistema "
            "con tu contraseña.",
            xalign=0,
            wrap=True,
        )
        admin.add_css_class("dato")
        caja.append(admin)

        self.auto = Gtk.Switch(valign=Gtk.Align.CENTER)
        self.auto.set_active(os.path.exists(f"{CONF}/inicio-automatico-de-serie"))
        auto_texto = Gtk.Label(
            label="entrar sin contraseña al encender\n"
            "(la pantalla se sigue bloqueando con ella)",
            xalign=0,
            hexpand=True,
        )
        auto_fila = Gtk.Box(spacing=12)
        auto_fila.append(auto_texto)
        auto_fila.append(self.auto)
        caja.append(auto_fila)

        self.error = Gtk.Label(xalign=0, wrap=True, max_width_chars=44)
        self.error.add_css_class("error")
        caja.append(self.error)

        self.boton = Gtk.Button(label="crear cuenta")
        self.boton.add_css_class("suggested-action")
        self.boton.connect("clicked", self.on_crear)
        caja.append(self.boton)

        self.set_child(fondo)
        self.nombre.grab_focus()

    def on_teclado(self, combo, _param):
        codigo = self.teclados[combo.get_selected()][0]
        if codigo == self.teclado:
            return
        os.makedirs(CONF, exist_ok=True)
        with open(f"{CONF}/kb_layout", "w", encoding="utf-8") as f:
            f.write(codigo + "\n")
        self.get_application().codigo = 3
        self.get_application().quit()

    def on_nombre(self, entrada):
        if not self.usuario_tocado:
            self.usuario.handler_block_by_func(self.on_usuario)
            self.usuario.set_text(usuario_desde(entrada.get_text()))
            self.usuario.handler_unblock_by_func(self.on_usuario)

    def on_usuario(self, _entrada):
        self.usuario_tocado = True

    def fallo(self, texto):
        self.error.set_text(texto)
        self.boton.set_sensitive(True)

    def on_crear(self, *_):
        usuario = self.usuario.get_text().strip()
        clave = self.clave.get_text()
        if not re.fullmatch(r"[a-z][a-z0-9_-]{0,31}", usuario):
            return self.fallo("usuario: minúsculas, números, - o _, empezando por una letra.")
        if len(clave) < MIN_CONTRASENA:
            return self.fallo(f"la contraseña tiene que tener al menos {MIN_CONTRASENA} caracteres.")
        if clave != self.clave2.get_text():
            return self.fallo("las contraseñas no coinciden.")
        self.boton.set_sensitive(False)
        self.error.set_text("")
        orden = [CREAR, "--usuario", usuario, "--teclado", self.teclado]
        if self.nombre.get_text().strip():
            orden += ["--nombre", self.nombre.get_text().strip()]
        if self.auto.get_active():
            orden.append("--inicio-auto")
        r = subprocess.run(orden, input=clave + "\n", capture_output=True, text=True)
        self.clave.set_text("")
        self.clave2.set_text("")
        if r.returncode != 0:
            return self.fallo(r.stderr.strip().removeprefix("crear-cuenta: ") or "no se pudo crear la cuenta.")
        self.error.remove_css_class("error")
        self.error.add_css_class("dato")
        self.error.set_text(f"cuenta {usuario} creada. entrando…")
        GLib.timeout_add(1200, self.get_application().quit)


class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.commandlab.PrimerArranque")
        self.codigo = 0

    def do_activate(self):
        cargar_tema()
        ventana = Asistente(self)
        ventana.fullscreen()
        ventana.present()


if __name__ == "__main__":
    app = App()
    app.run([])
    sys.exit(app.codigo)
