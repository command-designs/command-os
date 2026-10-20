#!/usr/bin/env python3
# Command OS — panel de la batería (ventana GTK 4 del escritorio; ajustes → batería o clic derecho en la
# batería de la barra). Enseña el estado y, solo si el portátil lo permite (charge_control_end_threshold), el límite de carga al 80 %. Ese lo pone lib/gestionar-bateria
# con pkexec (la sesión activa no necesita contraseña: system/polkit-gestionar-bateria.policy).
# docs/notas/escritorio.md § «Batería».
import sys

import bateria
from comun import PanelBase, administrar, boton, cargar_tema, traductor
from gi.repository import GLib, Gtk

HELPER = "/usr/lib/command-os/gestionar-bateria"
ANCHO = 520


class Panel(PanelBase):
    def __init__(self, app):
        _ = traductor()
        super().__init__(app, _, _("cmd-os · batería"), ANCHO)
        self.ocupado = False
        self.pintar()
        GLib.timeout_add_seconds(30, self.al_reloj)

    def interruptor(self, texto, activo, al_cambiar):
        fila = Gtk.Box(spacing=12)
        etiqueta = Gtk.Label(label=texto, xalign=0, hexpand=True, wrap=True, max_width_chars=44)
        fila.append(etiqueta)
        boton = Gtk.Switch(active=activo, valign=Gtk.Align.CENTER)
        boton.connect("state-set", al_cambiar)
        fila.append(boton)
        self.caja.append(fila)
        return boton

    def pintar(self, aviso="", error=True):
        _ = self._
        self.limpiar()
        titulo = Gtk.Label(label=_("› batería"), xalign=0)
        titulo.add_css_class("titulo")
        self.caja.append(titulo)
        d = bateria.estado()
        if d is None:
            texto = Gtk.Label(label=_("este equipo no tiene batería."), xalign=0, wrap=True, max_width_chars=50)
            texto.add_css_class("tenue")
            self.caja.append(texto)
        else:
            self.resumen = Gtk.Label(label=bateria.resumen(d, _), xalign=0)
            self.resumen.add_css_class("dato")
            self.caja.append(self.resumen)
            if d["limite"] is not None:
                self.interruptor(_("limitar la carga al 80 %"), d["limite"] < 100, self.al_limite)
                explica = Gtk.Label(
                    label=_("la batería dura más años si no pasa mucho tiempo al 100 %: con esto deja de cargar al "
                            "80 %. sirve sobre todo si el portátil pasa mucho tiempo enchufado; quítalo antes de un "
                            "viaje para tener la carga completa."),
                    xalign=0, wrap=True, max_width_chars=50,
                )
                explica.add_css_class("tenue")
                self.caja.append(explica)
        self.estado = Gtk.Label(label=aviso, xalign=0, wrap=True, max_width_chars=50)
        self.estado.add_css_class("error" if error else "dato")
        self.caja.append(self.estado)
        cerrar = boton(_("cerrar"), halign=Gtk.Align.END)
        cerrar.add_css_class("flat")
        cerrar.connect("clicked", lambda _b: self.ventana.close())
        self.caja.append(cerrar)

    def al_reloj(self):
        d = bateria.estado()
        if d is not None and not self.ocupado and getattr(self, "resumen", None) is not None:
            self.resumen.set_text(bateria.resumen(d, self._))
        return True

    def al_limite(self, boton, activo):
        _ = self._
        if self.ocupado:
            return True
        self.ocupado = True
        boton.set_sensitive(False)

        def hecho(codigo):
            self.ocupado = False
            if codigo is None:
                self.pintar(_("la carga se para en el 80 %.") if activo else _("la batería vuelve a cargar hasta el 100 %."),
                            error=False)
            elif codigo == "cancelado":
                self.pintar()
            else:
                self.pintar({
                    "rechazado": _("el portátil no aceptó el límite de carga."),
                    "no_soportado": _("este portátil no permite limitar la carga."),
                    "autenticacion": _("no se pudo comprobar la contraseña de administrador."),
                }.get(codigo, _("no se pudo completar la operación.")))
        self.en_hilo(lambda: administrar(HELPER, ["limite", "80" if activo else "no"]), hecho)
        return True  # el interruptor se repinta con el estado real al terminar


class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.commandlab.Bateria")
        self.panel = None

    def do_activate(self):
        cargar_tema()
        if self.panel is None:
            self.panel = Panel(self)
        self.panel.ventana.present()


if __name__ == "__main__":
    sys.exit(App().run([]))
