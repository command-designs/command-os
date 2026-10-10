#!/usr/bin/env python3
# Command OS — panel de actualizaciones (ventana GTK 4 del escritorio; clic en el aviso de la barra).
# Solo enseña lo que ya dejó la comprobación del sistema (`command-os-updates datos`) y lanza lo de
# siempre: «actualizar» abre `command-os-update` en una terminal (sudo y pacman piden confirmación)
# y «comprobar ahora» arranca la comprobación manual. No instala nada por sí mismo: docs/actualizaciones.md
# § 7 y docs/decisiones.md (por qué no se instala desde el panel).
#
# Una sola ventana por sesión: la aplicación es única (D-Bus), una segunda llamada trae la abierta.
import os
import subprocess
import sys
import threading

from comun import cargar_tema, traductor, ventana
from gi.repository import GLib, Gtk

ANCHO = 520
SIGNAL = 8  # el mismo que "signal" del módulo custom/updates de Waybar
# Filas de paquetes visibles sin desplazar la lista.
FILAS = 8


def leer_datos():
    """El estado de `command-os-updates datos`: {hace, nada, command-os, arch, paquetes} o None."""
    try:
        r = subprocess.run(["command-os-updates", "datos"], capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.SubprocessError):
        return None
    datos = {"hace": "", "nada": False, "command-os": None, "arch": False, "paquetes": []}
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
    return datos


def comprobar():
    """La comprobación manual (polkit la deja lanzar a la sesión local) y avisa a Waybar. True si fue bien."""
    try:
        r = subprocess.run(["systemctl", "start", "command-os-check-updates@manual.service"], timeout=300)
    except (OSError, subprocess.SubprocessError):
        return False
    subprocess.run(["pkill", f"-RTMIN+{SIGNAL}", "-u", str(os.getuid()), "-x", "waybar"], check=False)
    return r.returncode == 0


class Panel:
    def __init__(self, app):
        self._ = traductor()
        self.ventana, self.caja = ventana(app, self._("cmd-os · actualizaciones"), ANCHO)
        teclas = Gtk.EventControllerKey()
        teclas.connect("key-pressed", self.tecla)
        self.ventana.add_controller(teclas)
        self.pintar()

    def tecla(self, _controlador, valor, _codigo, _estado):
        # Escape cierra, como en los demás paneles.
        if valor == 0xFF1B:
            self.ventana.close()
            return True
        return False

    def limpiar(self):
        while (hijo := self.caja.get_first_child()) is not None:
            self.caja.remove(hijo)

    def pintar(self, aviso=""):
        _ = self._
        self.limpiar()
        datos = leer_datos()
        titulo = Gtk.Label(label=_("› actualizaciones"), xalign=0)
        titulo.add_css_class("titulo")
        self.caja.append(titulo)

        hay = bool(datos and (datos["command-os"] or datos["paquetes"]))
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
                cuenta = Gtk.Label(label=_("paquetes de Arch: {n}").format(n=len(datos["paquetes"])), xalign=0)
                cuenta.add_css_class("etiqueta")
                self.caja.append(cuenta)
                self.caja.append(self.lista(datos["paquetes"]))

        if datos and datos["hace"]:
            hace = Gtk.Label(label=_("comprobado {hace}").format(hace=datos["hace"]), xalign=0)
            hace.add_css_class("tenue")
            self.caja.append(hace)

        self.estado = Gtk.Label(label=aviso, xalign=0, wrap=True, max_width_chars=52)
        self.estado.add_css_class("error")
        self.caja.append(self.estado)

        botones = Gtk.Box(spacing=10, halign=Gtk.Align.END)
        cerrar = Gtk.Button(label=_("cerrar"))
        cerrar.add_css_class("flat")
        cerrar.connect("clicked", lambda _b: self.ventana.close())
        botones.append(cerrar)
        self.boton_comprobar = Gtk.Button(label=_("comprobar ahora"))
        self.boton_comprobar.connect("clicked", self.al_comprobar)
        botones.append(self.boton_comprobar)
        if hay:
            actualizar = Gtk.Button(label=_("actualizar"))
            actualizar.add_css_class("suggested-action")
            actualizar.connect("clicked", self.al_actualizar)
            botones.append(actualizar)
            self.ventana.set_default_widget(actualizar)
        self.caja.append(botones)

    def lista(self, paquetes):
        rejilla = Gtk.Grid(column_spacing=18, row_spacing=4)
        for i, (nombre, antes, despues) in enumerate(paquetes):
            rejilla.attach(Gtk.Label(label=nombre, xalign=0), 0, i, 1, 1)
            versiones = Gtk.Label(label=f"{antes} → {despues}", xalign=0, hexpand=True)
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
        # La terminal de command-os-update sigue su camino sola; el panel ya no hace falta.
        subprocess.Popen(["command-os-updates", "update"], start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.ventana.close()

    def al_comprobar(self, boton):
        _ = self._
        boton.set_sensitive(False)
        self.estado.set_text(_("buscando actualizaciones…"))
        threading.Thread(target=self.comprobar_en_hilo, daemon=True).start()

    def comprobar_en_hilo(self):
        bien = comprobar()
        GLib.idle_add(self.terminada, bien)

    def terminada(self, bien):
        _ = self._
        self.pintar("" if bien else _("no se pudo comprobar (¿sin red?)"))
        return False


class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.commandlab.Actualizaciones")
        self.panel = None

    def do_activate(self):
        cargar_tema()
        if self.panel is None:
            self.panel = Panel(self)
        self.panel.ventana.present()


if __name__ == "__main__":
    sys.exit(App().run([]))
