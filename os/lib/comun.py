# Command OS — piezas comunes de las ventanas GTK 4 de la entrada al equipo (lib/greeter.py y
# lib/primer-arranque.py): lectura del estado, traducciones, filas del formulario, tema y logo.
import os

import gi

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


def fila(etiqueta, widget):
    """Etiqueta en cian encima del campo."""
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
    """Panel central (filo rojo arriba) sobre el fondo; devuelve (fondo, panel).

    Va dentro de un ScrolledWindow: en una pantalla baja (1024x600) el formulario no cabe y, sin
    desplazamiento, el botón quedaría fuera de la pantalla. Si cabe, no se nota: sigue centrado."""
    caja = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
    caja.add_css_class("panel")
    caja.set_halign(Gtk.Align.CENTER)
    caja.set_valign(Gtk.Align.CENTER)
    caja.set_hexpand(True)
    caja.set_size_request(ancho, -1)
    desliza = Gtk.ScrolledWindow(
        hscrollbar_policy=Gtk.PolicyType.NEVER,
        vscrollbar_policy=Gtk.PolicyType.AUTOMATIC,
        hexpand=True,
        vexpand=True,
    )
    desliza.set_child(caja)
    fondo = Gtk.Box(hexpand=True)
    fondo.add_css_class("fondo")
    fondo.append(desliza)
    return fondo, caja


def cargar_tema():
    css = Gtk.CssProvider()
    if os.path.exists(CSS):
        css.load_from_path(CSS)
    Gtk.StyleContext.add_provider_for_display(
        Gdk.Display.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_USER
    )
