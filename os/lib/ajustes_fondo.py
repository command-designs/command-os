# Command OS — Ajustes → fondo (lib/ajustes.py). Los fondos de la marca con su miniatura; el elegido, con
# el filo Red Hot. Lo cambia command-os-wallpaper (guarda la elección en ~/.config/command-os/wallpaper y
# pone el fondo sin parpadeo). Las miniaturas se leen en un hilo: los fondos son de 4K.
import subprocess

from comun import Seccion, en_hilo
from gi.repository import Gdk, GdkPixbuf, Gtk

CARPETA = "/usr/share/command-os/wallpapers"
ANCHO, ALTO = 256, 144


def actual():
    try:
        r = subprocess.run(["command-os-wallpaper", "actual"], capture_output=True, text=True, timeout=5)
        return r.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        return ""


def miniatura(nombre):
    try:
        return GdkPixbuf.Pixbuf.new_from_file_at_scale(f"{CARPETA}/command-{nombre}.png", ANCHO, ALTO, True)
    except Exception:  # noqa: BLE001 — GLib.Error u otro: sin miniatura, el nombre basta
        return None


class Pagina(Seccion):
    def __init__(self, ventana, traducir):
        super().__init__(ventana, traducir)
        _ = self._
        # Los mismos nombres que command-os-wallpaper (NAMES y LABEL).
        self.fondos = [("reticula", _("retícula")), ("plano", _("plano"))]
        self.titulo(_("› fondo"))
        rejilla = Gtk.FlowBox(selection_mode=Gtk.SelectionMode.NONE, max_children_per_line=3,
                              column_spacing=16, row_spacing=16, homogeneous=True)
        self.botones = {}
        elegido = actual()
        for nombre, texto in self.fondos:
            b = Gtk.Button()
            b.add_css_class("fondo-muestra")
            caja = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
            imagen = Gtk.Picture(width_request=ANCHO, height_request=ALTO, can_shrink=True)
            caja.append(imagen)
            caja.append(Gtk.Label(label=texto, xalign=0))
            b.set_child(caja)
            b.connect("clicked", lambda _b, n=nombre: self.poner(n))
            if nombre == elegido:
                b.add_css_class("elegido")
            self.botones[nombre] = b
            rejilla.append(b)
            en_hilo(lambda n=nombre: miniatura(n),
                    lambda p, i=imagen: p is not None and i.set_paintable(Gdk.Texture.new_for_pixbuf(p)))
        self.caja.append(rejilla)
        self.estado = self.nota("")

    def poner(self, nombre):
        for n, b in self.botones.items():
            if n == nombre:
                b.add_css_class("elegido")
            else:
                b.remove_css_class("elegido")

        def trabajo():
            try:
                return subprocess.run(["command-os-wallpaper", "poner", nombre], capture_output=True,
                                      timeout=15).returncode == 0
            except (OSError, subprocess.SubprocessError):
                return False
        self.en_hilo(trabajo, lambda bien: self.estado.set_text("" if bien else self._("no se pudo cambiar el fondo.")))
