# Command OS — piezas comunes de las ventanas GTK 4 de la entrada al equipo (lib/greeter.py y
# lib/primer-arranque.py): lectura del estado, traducciones, filas del formulario, tema y logo.
import os
import subprocess
import re
import unicodedata

import gi

gi.require_version("Gdk", "4.0")
gi.require_version("Gtk", "4.0")
from gi.repository import Gdk, GdkPixbuf, Gtk  # noqa: E402
from traducir import DOMINIO, LOCALES, traductor  # noqa: E402,F401

CONF = "/etc/command-os"
CSS = "/usr/share/command-os/greeter/command.css"
LOGO = "/usr/share/command-os/logo/command-wordmark-white.png"


def leer(ruta, defecto=""):
    try:
        with open(ruta, encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return defecto


def disco_cifrado(cmdline="/proc/cmdline"):
    """True si el sistema arrancó desde un disco cifrado (`cryptdevice=` en la línea del kernel, que
    ponen el instalador de PC y command-os-rollback; docs/cifrado.md)."""
    return any(p.startswith("cryptdevice=") for p in leer(cmdline).split())


def usuario_desde(nombre):
    """«Daniel Infante» -> «daniel»: primera palabra, sin tildes, en minúsculas."""
    plano = unicodedata.normalize("NFKD", nombre).encode("ascii", "ignore").decode()
    palabra = (plano.lower().split() or [""])[0]
    return re.sub(r"[^a-z0-9_-]", "", palabra)[:32]


def fila(etiqueta, widget):
    """Etiqueta en Smoke encima del campo."""
    caja = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    texto = Gtk.Label(label=etiqueta, xalign=0)
    texto.add_css_class("etiqueta")
    caja.append(texto)
    caja.append(widget)
    return caja


def logo(alto):
    """El wordmark a una altura fija (a tamaño natural ensancharía todo el panel), o None."""
    if not os.path.exists(LOGO):
        return None
    imagen = GdkPixbuf.Pixbuf.new_from_file_at_scale(LOGO, 400, alto, True)
    pic = Gtk.Picture.new_for_paintable(Gdk.Texture.new_for_pixbuf(imagen))
    pic.set_content_fit(Gtk.ContentFit.SCALE_DOWN)
    # Sin esto el logo se encoge a 0 px cuando el panel no cabe y el panel se comprime en vez de
    # desplazarse (1024x600).
    pic.set_can_shrink(False)
    pic.set_halign(Gtk.Align.CENTER)
    return pic


def panel(ancho):
    """Panel central con chaflán sobre el fondo, enmarcado por las escuadras de la zona principal
    (marca v2, docs/DISENO.md); devuelve (fondo, panel).

    Va dentro de un ScrolledWindow: en una pantalla baja (1024x600) el formulario no cabe y, sin
    desplazamiento, el botón quedaría fuera de la pantalla. Si cabe, no se nota: sigue centrado."""
    caja = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
    caja.add_css_class("panel")
    caja.set_size_request(ancho, -1)
    marco = Gtk.Box()
    marco.add_css_class("escuadras")
    marco.set_halign(Gtk.Align.CENTER)
    marco.set_valign(Gtk.Align.CENTER)
    marco.set_hexpand(True)
    marco.append(caja)
    desliza = Gtk.ScrolledWindow(
        hscrollbar_policy=Gtk.PolicyType.NEVER,
        vscrollbar_policy=Gtk.PolicyType.AUTOMATIC,
        hexpand=True,
        vexpand=True,
    )
    desliza.set_child(marco)
    fondo = Gtk.Box(hexpand=True)
    fondo.add_css_class("fondo")
    fondo.append(desliza)
    return fondo, caja


def ventana(app, titulo, ancho, alto_max=640):
    """Ventana normal (no a pantalla completa) con el tema de Command OS: devuelve (ventana, caja).
    Paneles del escritorio (actualizaciones, cuentas, disco). Si el contenido es más alto que la
    pantalla, se desplaza (como `panel`)."""
    v = Gtk.ApplicationWindow(application=app, title=titulo)
    v.set_default_size(ancho, -1)
    v.set_resizable(False)
    caja = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
    caja.add_css_class("panel-ventana")
    caja.set_size_request(ancho, -1)
    desliza = Gtk.ScrolledWindow(
        hscrollbar_policy=Gtk.PolicyType.NEVER,
        vscrollbar_policy=Gtk.PolicyType.AUTOMATIC,
        propagate_natural_height=True,
        max_content_height=alto_max,
    )
    desliza.set_child(caja)
    v.set_child(desliza)
    return v, caja




def administrar(ayudante, args, entrada=""):
    """Ejecuta un ayudante de root (lib/gestionar-cuentas, lib/gestionar-disco) con pkexec: polkit pide la
    contraseña de un administrador y el panel no la ve. Devuelve None si fue bien o un código de error:
    el que da el ayudante («error: CÓDIGO»), `cancelado` (se cerró el diálogo de polkit) o `autenticacion`."""
    try:
        r = subprocess.run(["pkexec", ayudante, *args], input=entrada, capture_output=True, text=True, timeout=300)
    except (OSError, subprocess.SubprocessError):
        return "fallo"
    if r.returncode == 0:
        return None
    if r.returncode == 126:
        return "cancelado"
    if r.returncode == 127:
        return "autenticacion"
    m = re.search(r"error: (\w+)", r.stderr)
    return m.group(1) if m else "fallo"


class Dialogo(Gtk.Window):
    """Formulario modal. campos: [(clave, etiqueta, tipo, extra)]; tipos: texto, clave, interruptor, lista
    (extra = los nombres). al_aceptar(dialogo, valores) arranca el trabajo; el diálogo ya ha pasado a
    «ocupado» y lo cierra o le da un error cuando termina (cerrar_con / mostrar_error)."""

    def __init__(self, padre, titulo, intro, campos, texto_boton, al_aceptar, traducir, destacado=""):
        super().__init__(title=titulo, transient_for=padre, modal=True, resizable=False)
        self._ = _ = traducir
        self.al_aceptar = al_aceptar
        self.widgets = {}
        caja = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        caja.add_css_class("panel-ventana")
        caja.set_size_request(440, -1)
        cabecera = Gtk.Label(label=f"› {titulo}", xalign=0)
        cabecera.add_css_class("titulo")
        caja.append(cabecera)
        if intro:
            texto = Gtk.Label(label=intro, xalign=0, wrap=True, max_width_chars=48)
            texto.add_css_class("tenue")
            caja.append(texto)
        if destacado:
            # Un dato que hay que leer con calma (la clave de recuperación): monoespaciado.
            grande = Gtk.Label(label=destacado, xalign=0)
            grande.add_css_class("clave")
            caja.append(grande)
        for clave, etiqueta, tipo, extra in campos:
            if tipo == "texto":
                w = Gtk.Entry()
                w.connect("activate", self.aceptar)
            elif tipo == "clave":
                w = Gtk.PasswordEntry(show_peek_icon=True)
                w.connect("activate", self.aceptar)
            elif tipo == "interruptor":
                w = Gtk.Switch(halign=Gtk.Align.START)
            else:
                w = Gtk.DropDown.new_from_strings(extra)
            self.widgets[clave] = (tipo, w)
            caja.append(fila(etiqueta, w))
        self.error = Gtk.Label(xalign=0, wrap=True, max_width_chars=48)
        self.error.add_css_class("error")
        caja.append(self.error)
        botones = Gtk.Box(spacing=10, halign=Gtk.Align.END)
        cancelar = Gtk.Button(label=_("cancelar"))
        cancelar.add_css_class("flat")
        cancelar.connect("clicked", lambda _b: self.close())
        botones.append(cancelar)
        self.boton = Gtk.Button(label=texto_boton)
        self.boton.add_css_class("suggested-action")
        self.boton.connect("clicked", self.aceptar)
        botones.append(self.boton)
        caja.append(botones)
        self.set_child(caja)
        teclas = Gtk.EventControllerKey()
        teclas.connect("key-pressed", self.tecla)
        self.add_controller(teclas)

    def tecla(self, _controlador, valor, _codigo, _estado):
        if valor == 0xFF1B:  # Escape
            self.close()
            return True
        return False

    def valores(self):
        v = {}
        for clave, (tipo, w) in self.widgets.items():
            if tipo in ("texto", "clave"):
                v[clave] = w.get_text()
            elif tipo == "interruptor":
                v[clave] = w.get_active()
            else:
                v[clave] = w.get_selected()
        return v

    def aceptar(self, *_args):
        if not self.boton.get_sensitive():
            return
        motivo = self.al_aceptar(self, self.valores())
        if motivo:
            self.mostrar_error(motivo)
        else:
            self.error.set_text("")
            self.boton.set_sensitive(False)

    def mostrar_error(self, texto):
        self.error.set_text(texto)
        self.boton.set_sensitive(True)


def cargar_tema():
    css = Gtk.CssProvider()
    if os.path.exists(CSS):
        css.load_from_path(CSS)
    Gtk.StyleContext.add_provider_for_display(
        Gdk.Display.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_USER
    )
