#!/usr/bin/env python3
# Command OS — asistente de primer arranque (ventana GTK 4 a pantalla completa dentro de cage, como
# root). Pide idioma, teclado, nombre, usuario y contraseña, y si se entra solo al encender; crea la
# cuenta con /usr/lib/command-os/crear-cuenta (la contraseña va por la entrada estándar, nunca en
# argumentos ni registros), que también aplica el idioma. Lo lanza command-os-primer-arranque.
#
# El idioma cambia la ventana al momento y se aplica al sistema al crear la cuenta (antes no se toca
# nada). Se recuerda en $XDG_RUNTIME_DIR/idioma por si se cambia el teclado, que reabre cage.
#
# Códigos de salida: 0 cuenta creada · 3 cambio de teclado (el lanzador vuelve a abrir cage con la
# distribución nueva, para que lo que se escriba ya salga con ella).
import os
import re
import subprocess
import sys
import threading
import unicodedata

from comun import CONF, cargar_tema, fila, leer, logo, panel, traductor
from gi.repository import GLib, Gtk

CREAR = "/usr/lib/command-os/crear-cuenta"
MIN_CONTRASENA = 8
ELEGIDO = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/run/command-os-primer-arranque"), "idioma")


def N_(texto):
    """Marca un texto para traducir sin traducirlo aún (se traduce al pintar la ventana)."""
    return texto


TECLADOS = [
    ("es", N_("español (España)")),
    ("latam", N_("español (Latinoamérica)")),
    ("us", N_("inglés (EE. UU.)")),
    ("gb", N_("inglés (Reino Unido)")),
    ("pt", N_("portugués (Portugal)")),
    ("br", N_("portugués (Brasil)")),
    ("fr", N_("francés")),
    ("de", N_("alemán")),
    ("it", N_("italiano")),
]


def idiomas():
    """[(locale, nombre en su idioma)] de command-os-idioma: la lista vive en un solo sitio."""
    try:
        r = subprocess.run(["command-os-idioma", "lista"], capture_output=True, text=True, check=True)
        lista = [tuple(linea.split(" ", 1)) for linea in r.stdout.splitlines() if " " in linea]
    except (OSError, subprocess.CalledProcessError):
        lista = []
    return lista or [("es_ES.UTF-8", "español")]


def idioma_inicial(lista):
    """El elegido antes de reabrir cage o, si no, el del sistema (LANG); si no está, el primero."""
    for pedido in (leer(ELEGIDO), os.environ.get("LANG", "")):
        base = pedido.split(".")[0]
        for codigo, _nombre in lista:
            if base and codigo.split(".")[0] == base:
                return codigo
    return lista[0][0]


def usuario_desde(nombre):
    """«Daniel Infante» -> «daniel»: primera palabra, sin tildes, en minúsculas."""
    plano = unicodedata.normalize("NFKD", nombre).encode("ascii", "ignore").decode()
    palabra = (plano.lower().split() or [""])[0]
    return re.sub(r"[^a-z0-9_-]", "", palabra)[:32]


class Asistente(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app)
        self.usuario_tocado = False
        self.teclado = leer(f"{CONF}/kb_layout", "es")
        self.idiomas = idiomas()
        self.idioma = idioma_inicial(self.idiomas)
        # Si el instalador dejó otra distribución (us-intl, de(nodeadkeys)…), sale la primera y
        # seleccionada: la lista nunca enseña un teclado distinto del que se está usando.
        self.teclados = list(TECLADOS)
        if self.teclado not in [c for c, _ in self.teclados]:
            self.teclados.insert(0, (self.teclado, None))
        self.construir()
        self.nombre.grab_focus()

    def construir(self, valores=None):
        """Pinta la ventana en self.idioma. Con valores (de un cambio de idioma), los conserva."""
        _ = self._ = traductor(self.idioma)
        self.set_title(_("cmd-os · primer arranque"))
        fondo, caja = panel(460)
        marca = logo(44)
        if marca:
            caja.append(marca)

        titulo = Gtk.Label(label=_("› primer arranque"), xalign=0)
        titulo.add_css_class("titulo")
        caja.append(titulo)
        intro = Gtk.Label(
            label=_("crea la cuenta con la que vas a usar este equipo."), xalign=0, wrap=True
        )
        intro.add_css_class("tenue")
        caja.append(intro)

        # Idioma y teclado: lo primero, para que el resto ya salga en ese idioma y se escriba con él.
        self.combo_idioma = Gtk.DropDown.new_from_strings([n for _c, n in self.idiomas])
        self.combo_idioma.set_selected([c for c, _n in self.idiomas].index(self.idioma))
        self.combo_idioma.connect("notify::selected", self.on_idioma)
        caja.append(fila(_("idioma"), self.combo_idioma))

        nombres = [
            _(n) if n else _("{teclado} (del instalador)").format(teclado=c) for c, n in self.teclados
        ]
        self.combo = Gtk.DropDown.new_from_strings(nombres)
        self.combo.set_selected([c for c, _n in self.teclados].index(self.teclado))
        self.combo.connect("notify::selected", self.on_teclado)
        caja.append(fila(_("teclado"), self.combo))

        self.nombre = Gtk.Entry(placeholder_text=_("opcional"))
        self.nombre.connect("changed", self.on_nombre)
        caja.append(fila(_("tu nombre"), self.nombre))

        self.usuario = Gtk.Entry(placeholder_text=_("minúsculas, sin espacios"))
        self.usuario.connect("changed", self.on_usuario)
        caja.append(fila(_("usuario"), self.usuario))

        self.clave = Gtk.PasswordEntry(show_peek_icon=True)
        self.clave.set_property(
            "placeholder-text", _("al menos {n} caracteres").format(n=MIN_CONTRASENA)
        )
        caja.append(fila(_("contraseña"), self.clave))
        self.clave2 = Gtk.PasswordEntry(show_peek_icon=True)
        self.clave2.connect("activate", self.on_crear)
        caja.append(fila(_("repítela"), self.clave2))

        admin = Gtk.Label(
            label=_("esta cuenta administra el equipo: instala programas y cambia el sistema "
                    "con tu contraseña."),
            xalign=0,
            wrap=True,
        )
        admin.add_css_class("dato")
        caja.append(admin)

        self.auto = Gtk.Switch(valign=Gtk.Align.CENTER)
        self.auto.set_active(os.path.exists(f"{CONF}/inicio-automatico-de-serie"))
        auto_texto = Gtk.Label(
            label=_("entrar sin contraseña al encender\n(la pantalla se sigue bloqueando con ella)"),
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

        self.boton = Gtk.Button(label=_("crear cuenta"))
        self.boton.add_css_class("suggested-action")
        self.boton.connect("clicked", self.on_crear)
        caja.append(self.boton)

        if valores:
            tocado = valores["tocado"]
            self.nombre.set_text(valores["nombre"])  # rellena el usuario si no se había tocado
            self.usuario.set_text(valores["usuario"])
            self.usuario_tocado = tocado
            self.clave.set_text(valores["clave"])
            self.clave2.set_text(valores["clave2"])
            self.auto.set_active(valores["auto"])
        self.set_child(fondo)

    def on_idioma(self, combo, _param):
        codigo = self.idiomas[combo.get_selected()][0]
        if codigo == self.idioma:
            return
        self.idioma = codigo
        try:
            with open(ELEGIDO, "w", encoding="utf-8") as f:
                f.write(codigo + "\n")
        except OSError:
            pass  # solo se perdería al cambiar de teclado
        valores = {
            "nombre": self.nombre.get_text(), "usuario": self.usuario.get_text(),
            "tocado": self.usuario_tocado, "clave": self.clave.get_text(),
            "clave2": self.clave2.get_text(), "auto": self.auto.get_active(),
        }
        # Al terminar la señal: no se destruye el desplegable mientras la está emitiendo.
        GLib.idle_add(self.repintar, valores)

    def repintar(self, valores):
        self.construir(valores)
        self.combo_idioma.grab_focus()
        return False

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
        self.error.remove_css_class("dato")
        self.error.add_css_class("error")
        self.error.set_text(texto)
        self.boton.set_sensitive(True)
        self.combo_idioma.set_sensitive(True)
        self.combo.set_sensitive(True)

    def on_crear(self, *_args):
        _ = self._
        if not self.boton.get_sensitive():
            return  # ya se está creando
        usuario = self.usuario.get_text().strip()
        clave = self.clave.get_text()
        if not re.fullmatch(r"[a-z][a-z0-9_-]{0,31}", usuario):
            return self.fallo(_("usuario: minúsculas, números, - o _, empezando por una letra."))
        if len(clave) < MIN_CONTRASENA:
            return self.fallo(
                _("la contraseña tiene que tener al menos {n} caracteres.").format(n=MIN_CONTRASENA)
            )
        if clave != self.clave2.get_text():
            return self.fallo(_("las contraseñas no coinciden."))
        for w in (self.boton, self.combo_idioma, self.combo):
            w.set_sensitive(False)
        self.error.remove_css_class("error")
        self.error.add_css_class("dato")
        self.error.set_text(_("creando la cuenta…"))
        orden = [CREAR, "--usuario", usuario, "--teclado", self.teclado, "--idioma", self.idioma]
        if self.nombre.get_text().strip():
            orden += ["--nombre", self.nombre.get_text().strip()]
        if self.auto.get_active():
            orden.append("--inicio-auto")
        self.clave.set_text("")
        self.clave2.set_text("")
        # En un hilo: aplicar el idioma rehace el menú de arranque (unos segundos) y la ventana no
        # debe congelarse.
        threading.Thread(target=self.crear, args=(orden, clave, usuario), daemon=True).start()

    def crear(self, orden, clave, usuario):
        entorno = dict(os.environ, LANG=self.idioma)
        r = subprocess.run(orden, input=clave + "\n", capture_output=True, text=True, env=entorno)
        GLib.idle_add(self.creada, r, usuario)

    def creada(self, r, usuario):
        _ = self._
        if r.returncode != 0:
            # crear-cuenta da sus errores ya traducidos (corre con LANG del idioma elegido).
            motivo = (r.stderr.strip().splitlines() or [""])[-1].removeprefix("crear-cuenta: ")
            self.fallo(motivo or _("no se pudo crear la cuenta."))
            return False
        self.error.set_text(_("cuenta {usuario} creada. entrando…").format(usuario=usuario))
        GLib.timeout_add(1200, self.get_application().quit)
        return False


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
