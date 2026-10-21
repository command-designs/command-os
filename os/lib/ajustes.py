#!/usr/bin/env python3
# Command OS — Ajustes: una ventana con las secciones a la izquierda (wi-fi, bluetooth, barra, pantalla,
# sonido, fondo, batería, cuentas, disco, actualizaciones, idioma y hora, sistema) y la elegida a la
# derecha, cada una con lo de todos los días y, al final, «avanzado» con la herramienta completa.
#
#     command-os-ajustes [SECCIÓN]
#
# Ligera (AGENTS.md § «Ligereza»): cada sección se importa y se construye la primera vez que se abre, lo
# que se pone al día solo corre solo en la sección a la vista y al cerrar la ventana no queda nada en
# memoria. La aplicación es única por sesión (D-Bus): una segunda llamada trae la ventana abierta y va a
# la sección pedida. Las secciones que no tienen sentido en el equipo (bluetooth sin adaptador, batería
# en un sobremesa, disco sin cifrar) no salen. docs/notas/escritorio.md § «Ajustes y centro de control».
import glob
import importlib
import os
import sys
import traceback

import bateria
from comun import cargar_tema, disco_cifrado, escape_cierra, traductor
from gi.repository import Gdk, Gio, Gtk

ANCHO, ALTO = 940, 660
MARGEN = 48  # lo que se deja alrededor en una pantalla pequeña
BARRA = 36


def hay_bluetooth():
    return bool(glob.glob(os.path.join(os.environ.get("COMMAND_OS_BLUETOOTH_SYS", "/sys/class/bluetooth"), "hci*")))


# Las que solo salen en algunos equipos.
DISPONIBLE = {
    "bluetooth": hay_bluetooth,
    "bateria": lambda: bateria.estado() is not None,
    "disco": disco_cifrado,
}

# Otros nombres con los que se puede pedir una sección (órdenes de antes y atajos).
ALIAS = {"wifi": "red", "wi-fi": "red", "hora": "idioma", "zona": "idioma", "about": "sistema"}


def secciones(traducir):
    """[(clave, módulo, icono, nombre)] en el orden de la lista, solo las que tienen sentido aquí."""
    _ = traducir
    todas = [
        ("red", "ajustes_red", "network-wireless-symbolic", _("wi-fi y red")),
        ("bluetooth", "ajustes_bluetooth", "bluetooth-symbolic", _("bluetooth")),
        ("barra", "ajustes_barra", "view-app-grid-symbolic", _("barra")),
        ("pantalla", "ajustes_pantalla", "video-display-symbolic", _("pantalla")),
        ("sonido", "ajustes_sonido", "audio-speakers-symbolic", _("sonido")),
        ("fondo", "ajustes_fondo", "preferences-desktop-wallpaper-symbolic", _("fondo")),
        ("bateria", "ajustes_bateria", "battery-good-symbolic", _("batería")),
        ("cuentas", "ajustes_cuentas", "system-users-symbolic", _("cuentas")),
        ("disco", "ajustes_disco", "drive-harddisk-symbolic", _("disco cifrado")),
        ("actualizaciones", "ajustes_actualizaciones", "software-update-available-symbolic", _("actualizaciones")),
        ("idioma", "ajustes_idioma", "globe-symbolic", _("idioma y hora")),
        ("sistema", "ajustes_sistema", "computer-symbolic", _("sistema")),
    ]
    return [s for s in todas if DISPONIBLE.get(s[0], lambda: True)()]


def tamano():
    """El de serie, o menos si la pantalla es pequeña (1024x600): la ventana siempre cabe."""
    try:
        monitores = Gdk.Display.get_default().get_monitors()
        g = monitores.get_item(0).get_geometry()
        return min(ANCHO, g.width - MARGEN), min(ALTO, g.height - BARRA - MARGEN)
    except (AttributeError, TypeError):
        return ANCHO, ALTO


class Ventana:
    def __init__(self, app):
        self._ = _ = traductor()
        self.v = Gtk.ApplicationWindow(application=app, title=_("cmd-os · ajustes"))
        self.v.set_default_size(*tamano())
        escape_cierra(self.v)
        self.lista_secciones = secciones(_)
        self.paginas = {}  # clave -> Seccion (o None si falló)
        self.actual = None
        self.entra = 0

        cuerpo = Gtk.Box()
        lateral = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        lateral.add_css_class("lateral")
        cabecera = Gtk.Label(label=_("› ajustes"), xalign=0)
        cabecera.add_css_class("titulo")
        lateral.append(cabecera)
        self.lista = Gtk.ListBox(selection_mode=Gtk.SelectionMode.SINGLE)
        self.lista.add_css_class("secciones")
        for clave, _modulo, icono, nombre in self.lista_secciones:
            fila = Gtk.ListBoxRow()
            fila.clave = clave
            caja = Gtk.Box(spacing=12)
            caja.append(Gtk.Image.new_from_icon_name(icono))
            caja.append(Gtk.Label(label=nombre, xalign=0))
            fila.set_child(caja)
            self.lista.append(fila)
        self.lista.connect("row-selected", self.al_elegir)
        desliza = Gtk.ScrolledWindow(hscrollbar_policy=Gtk.PolicyType.NEVER, vexpand=True)
        desliza.set_child(self.lista)
        lateral.append(desliza)
        cuerpo.append(lateral)

        self.pila = Gtk.Stack(hexpand=True, vexpand=True)
        self.pila.add_css_class("contenido")
        cuerpo.append(self.pila)
        self.v.set_child(cuerpo)

    def ir(self, clave):
        """Enseña la sección pedida (o la primera si no está en este equipo)."""
        clave = ALIAS.get(clave, clave)
        filas = {}
        i = 0
        while (fila := self.lista.get_row_at_index(i)) is not None:
            filas[fila.clave] = fila
            i += 1
        fila = filas.get(clave) or self.lista.get_row_at_index(0)
        if fila is not None:
            if self.lista.get_selected_row() is fila:
                self.al_elegir(self.lista, fila)
            else:
                self.lista.select_row(fila)

    def pagina(self, clave):
        """La sección construida (la primera vez, se importa y se construye)."""
        if clave in self.paginas:
            return self.paginas[clave]
        modulo = next(m for c, m, _i, _n in self.lista_secciones if c == clave)
        try:
            pagina = importlib.import_module(modulo).Pagina(self.v, self._)
            contenido = pagina.caja
        except Exception:  # noqa: BLE001 — una sección rota no puede tirar Ajustes entero
            traceback.print_exc()
            pagina = None
            contenido = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
            contenido.add_css_class("seccion")
            error = Gtk.Label(label=self._("esta sección no se pudo abrir."), xalign=0)
            error.add_css_class("error")
            contenido.append(error)
        desliza = Gtk.ScrolledWindow(hscrollbar_policy=Gtk.PolicyType.NEVER)
        desliza.set_child(contenido)
        self.pila.add_named(desliza, clave)
        self.paginas[clave] = pagina
        return pagina

    def al_elegir(self, _lista, fila):
        if fila is None:
            return
        if self.actual is not None and self.paginas.get(self.actual) is not None and self.actual != fila.clave:
            self.paginas[self.actual].ocultar()
        pagina = self.pagina(fila.clave)
        self.pila.set_visible_child_name(fila.clave)
        hijo = self.pila.get_visible_child()
        # La sección entra con el fundido y el desliz de los paneles (command.css): cambiar de clase
        # vuelve a lanzar la animación, también al volver a una ya abierta.
        self.entra = 1 - self.entra
        hijo.remove_css_class("entra-a" if self.entra else "entra-b")
        hijo.add_css_class("entra-b" if self.entra else "entra-a")
        if pagina is not None and self.actual != fila.clave:
            pagina.mostrar()
        self.actual = fila.clave


class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.commandlab.Ajustes", flags=Gio.ApplicationFlags.HANDLES_COMMAND_LINE)
        self.ventana = None

    def do_command_line(self, linea):
        args = linea.get_arguments()[1:]
        if self.ventana is None:
            cargar_tema()
            self.ventana = Ventana(self)
        self.ventana.ir(args[0] if args else (self.ventana.actual or ""))
        self.ventana.v.present()
        return 0


if __name__ == "__main__":
    sys.exit(App().run(sys.argv))
