# Command OS — Ajustes → actualizaciones (lib/ajustes.py; también clic en el aviso de la barra).
# Solo enseña lo que ya dejó la comprobación del sistema (`command-os-updates datos`) y lanza lo de
# siempre: «actualizar» abre `command-os-update` en una terminal (sudo y pacman piden confirmación)
# y «comprobar ahora» arranca la comprobación manual. No instala nada por sí mismo: docs/actualizaciones.md
# § 7 y docs/decisiones/README.md (por qué no se instala desde el panel).
import os
import subprocess

from comun import Seccion, boton, lanzar
from gi.repository import Gtk

SIGNAL = 8  # el mismo que "signal" del módulo custom/updates de Waybar
# Filas de paquetes visibles sin desplazar la lista.
FILAS = 8


def leer_datos():
    """El estado de `command-os-updates datos`: {hace, nada, command-os, arch, paquetes, apps} o None."""
    try:
        r = subprocess.run(["command-os-updates", "datos"], capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.SubprocessError):
        return None
    datos = {"hace": "", "nada": False, "command-os": None, "arch": False, "paquetes": [], "apps": []}
    for linea in r.stdout.splitlines():
        c = linea.split("\t")
        if c[0] == "nada":
            datos["nada"] = True
        elif c[0] == "hace" and len(c) > 1:
            datos["hace"] = c[1]
        elif c[0] == "command-os" and len(c) == 3:
            datos["command-os"] = (c[1], c[2])
        elif c[0] == "arch" and len(c) > 1:
            datos["arch"] = c[1] == "1"
        elif c[0] == "paquete" and len(c) == 4:
            datos["paquetes"].append(tuple(c[1:]))
        elif c[0] == "app" and len(c) == 4:
            datos["apps"].append(tuple(c[1:]))
    return datos


def comprobar():
    """La comprobación manual (polkit la deja lanzar a la sesión local) y avisa a Waybar. True si fue bien."""
    try:
        r = subprocess.run(["systemctl", "start", "command-os-check-updates@manual.service"], timeout=300)
    except (OSError, subprocess.SubprocessError):
        return False
    subprocess.run(["pkill", f"-RTMIN+{SIGNAL}", "-u", str(os.getuid()), "-x", "waybar"], check=False)
    return r.returncode == 0


class Pagina(Seccion):
    def __init__(self, ventana, traducir):
        super().__init__(ventana, traducir)
        self.leyendo = False
        self.pintar()

    def al_mostrar(self):
        self.pintar()

    def pintar(self, aviso=""):
        """Lee el estado en un hilo (command-os-updates datos puede tardar) y lo pinta al llegar."""
        if self.leyendo:
            return
        self.leyendo = True
        if self.caja.get_first_child() is None:
            self.titulo(self._("› actualizaciones"))
            self.nota(self._("leyendo…"))

        def hecho(datos):
            self.leyendo = False
            self.pintar_datos(datos, aviso)
        self.en_hilo(leer_datos, hecho)

    def pintar_datos(self, datos, aviso):
        _ = self._
        self.limpiar()
        self.titulo(_("› actualizaciones"))

        hay = bool(datos and (datos["command-os"] or datos["paquetes"] or datos["apps"]))
        if datos is None or (datos["nada"] and not datos["hace"]):
            resumen = _("no hay una comprobación reciente: pulsa «comprobar ahora».")
        elif not hay:
            resumen = _("el sistema está al día.")
        else:
            resumen = ""
        if resumen:
            texto = Gtk.Label(label=resumen, xalign=0, wrap=True, max_width_chars=52)
            texto.add_css_class("tenue")
            self.caja.append(texto)

        if hay:
            if datos["command-os"]:
                actual, nuevo = datos["command-os"]
                v = Gtk.Label(label=f"command-os  {actual} → {nuevo}", xalign=0)
                v.add_css_class("dato")
                self.caja.append(v)
                if datos["arch"]:
                    nota = Gtk.Label(
                        label=_("al actualizar se aplica también la fecha de Arch validada con esa versión"),
                        xalign=0, wrap=True, max_width_chars=52,
                    )
                    nota.add_css_class("tenue")
                    self.caja.append(nota)
            if datos["paquetes"]:
                cuenta = Gtk.Label(label=_("paquetes de Arch: {n}").format(n=len(datos["paquetes"])).upper(), xalign=0)
                cuenta.add_css_class("etiqueta")
                self.caja.append(cuenta)
                self.caja.append(self.lista(datos["paquetes"]))
            if datos["apps"]:
                cuenta = Gtk.Label(label=_("aplicaciones de la tienda: {n}").format(n=len(datos["apps"])).upper(), xalign=0)
                cuenta.add_css_class("etiqueta")
                self.caja.append(cuenta)
                self.caja.append(self.lista(datos["apps"]))

        if datos and datos["hace"]:
            hace = Gtk.Label(label=_("comprobado {hace}").format(hace=datos["hace"]), xalign=0)
            hace.add_css_class("tenue")
            self.caja.append(hace)

        self.estado = Gtk.Label(label=aviso, xalign=0, wrap=True, max_width_chars=52)
        self.estado.add_css_class("error")
        self.caja.append(self.estado)

        botones = Gtk.Box(spacing=10, halign=Gtk.Align.START)
        self.boton_comprobar = boton(_("comprobar ahora"))
        self.boton_comprobar.connect("clicked", self.al_comprobar)
        botones.append(self.boton_comprobar)
        if hay:
            actualizar = boton(_("actualizar"))
            actualizar.add_css_class("suggested-action")
            actualizar.connect("clicked", self.al_actualizar)
            botones.append(actualizar)
        self.caja.append(botones)

    def lista(self, paquetes):
        rejilla = Gtk.Grid(column_spacing=18, row_spacing=4)
        for i, (nombre, antes, despues) in enumerate(paquetes):
            rejilla.attach(Gtk.Label(label=nombre, xalign=0), 0, i, 1, 1)
            # Las aplicaciones de la tienda pueden no tener versión (o solo la nueva).
            texto = f"{antes} → {despues}" if antes and despues and antes != despues else despues
            versiones = Gtk.Label(label=texto, xalign=0, hexpand=True)
            versiones.add_css_class("tenue")
            rejilla.attach(versiones, 1, i, 1, 1)
        desliza = Gtk.ScrolledWindow(
            hscrollbar_policy=Gtk.PolicyType.NEVER,
            propagate_natural_height=True,
            max_content_height=FILAS * 26,
        )
        desliza.set_child(rejilla)
        return desliza

    def al_actualizar(self, _boton):
        # La terminal de command-os-update sigue su camino sola.
        lanzar(["command-os-updates", "update"])

    def al_comprobar(self, boton):
        _ = self._
        boton.set_sensitive(False)
        self.estado.set_text(_("buscando actualizaciones…"))
        self.en_hilo(comprobar, self.terminada)

    def terminada(self, bien):
        _ = self._
        self.pintar("" if bien else _("no se pudo comprobar (¿sin red?)"))

