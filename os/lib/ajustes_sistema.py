# Command OS — Ajustes → sistema (lib/ajustes.py). Lo de «acerca de cmd-os» (command-os-about datos: versión,
# Arch validado, equipo, hardware y si se puede volver atrás) y, en «avanzado», las herramientas técnicas
# que ya no salen en el lanzador: el monitor del sistema (btop) y el mapa del hardware (lstopo).
import shutil
import subprocess

from comun import Seccion
from gi.repository import Gtk


def datos():
    """[(etiqueta, valor)] de command-os-about datos (ya en el idioma de la sesión)."""
    try:
        r = subprocess.run(["command-os-about", "datos"], capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.SubprocessError):
        return []
    return [tuple(linea.split("\t", 1)) for linea in r.stdout.splitlines() if "\t" in linea]


class Pagina(Seccion):
    def __init__(self, ventana, traducir):
        super().__init__(ventana, traducir)
        _ = self._
        self.titulo(_("› sistema"))
        self.rejilla = Gtk.Grid(column_spacing=24, row_spacing=8)
        self.caja.append(self.rejilla)
        self.espera = self.nota(_("leyendo…"))
        self.en_hilo(datos, self.pintar)
        herramientas = [(_("monitor del sistema"), ["kitty", "--class", "btop", "-e", "btop"])]
        if shutil.which("lstopo"):
            herramientas.append((_("mapa del hardware"), ["lstopo"]))
        herramientas.append((_("más detalle en la terminal (fastfetch)"), ["kitty", "--hold", "fastfetch"]))
        self.avanzado(herramientas)

    def pintar(self, filas):
        self.espera.set_text("" if filas else self._("no se pudo leer la información del sistema."))
        for i, (etiqueta, valor) in enumerate(filas):
            e = Gtk.Label(label=etiqueta.upper(), xalign=0, yalign=0)
            e.add_css_class("etiqueta")
            self.rejilla.attach(e, 0, i, 1, 1)
            v = Gtk.Label(label=valor, xalign=0, wrap=True, max_width_chars=50, selectable=True)
            v.add_css_class("dato")
            self.rejilla.attach(v, 1, i, 1, 1)
