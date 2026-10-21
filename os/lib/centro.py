#!/usr/bin/env python3
# Command OS — centro de control: el panel que cuelga de la barra al hacer clic en el grupo de estado (red,
# Bluetooth, volumen, batería). Wi-Fi y Bluetooth (encender o apagar, y la flecha a las redes o a
# Ajustes), volumen y brillo, la batería y el botón a Ajustes.
#
#     command-os-centro [redes]
#
# Se abre al usarlo y se cierra al perder el foco, con Escape o con otro clic en la barra: nada se queda en
# memoria (AGENTS.md § «Ligereza»). Ventana GTK 4 sin decorar y transparente con el panel con chaflán; la
# coloca una regla de labwc (rc.xml, dev.commandlab.Centro…) junto al grupo de estado de la barra. Lo que sale se
# decide mirando /sys; los datos llegan en un hilo después de enseñarse: abrir no espera a nmcli ni a
# bluetoothctl. docs/notas/escritorio.md § «Ajustes y centro de control».
import os
import sys
import time

import bateria
import bt
import fijadas
import red
import sonido
from comun import Deslizador, boton, cargar_tema, en_hilo, escape_cierra, lanzar, traductor
from gi.repository import Gio, GLib, Gtk, Pango
from redes import ListaRedes

ANCHO = 380
CADA = 5  # segundos entre lecturas mientras está abierto (teclas de volumen, la red que entra sola…)
# Si el clic en la barra le quita el foco, el panel se cierra antes de que llegue la orden de ese mismo
# clic: una orden tan seguida al cierre era para cerrarlo, no para volver a abrirlo.
REPETIDO = 0.5
# Dónde cuelga, según el lado de la barra (Ajustes → Barra): labwc lo coloca con una regla por sitio, que
# mira el id de la ventana (rc.xml). Con la barra arriba, bajo ella a la derecha; abajo o a la derecha, en
# la esquina de abajo a la derecha, y a la izquierda, en la de abajo a la izquierda (el grupo de estado va
# al final de la barra).
LADO = fijadas.ajustes()["lado"]
IDS = {"arriba": "dev.commandlab.Centro", "abajo": "dev.commandlab.CentroAbajo",
       "derecha": "dev.commandlab.CentroAbajo", "izquierda": "dev.commandlab.CentroIzquierda"}
# Colgado de abajo, si creciera se saldría de la pantalla por abajo: labwc no lo vuelve a colocar. Así
# que la lista de redes tiene un alto fijo y, al cambiar de página, el panel se abre otra vez.
DESDE_ABAJO = LADO != "arriba"


def marca_cierre():
    return os.path.join(GLib.get_user_runtime_dir(), "command-os", "centro-cerrado")


def cerrado_hace_poco():
    try:
        return 0 <= time.time() - os.path.getmtime(marca_cierre()) < REPETIDO
    except OSError:
        return False


def apuntar_cierre():
    try:
        os.makedirs(os.path.dirname(marca_cierre()), exist_ok=True)
        with open(marca_cierre(), "w", encoding="utf-8"):
            pass
    except OSError:
        pass


def leer_estado():
    """Todo lo que enseña el panel (en un hilo: nmcli y bluetoothctl tardan)."""
    hay_wifi = red.dispositivo_wifi() is not None
    bt_on = bt.encendido()
    return {
        "hay_wifi": hay_wifi,
        "wifi": hay_wifi and red.wifi_encendido(),
        "conexion": red.conexion(),
        "bt": bt_on,
        "bt_conectados": [d["nombre"] for d in bt.dispositivos() if d["conectado"]] if bt_on else [],
        "volumen": sonido.volumen(),
        "brillo": sonido.brillo(),
        "bateria": bateria.estado(),
    }


def icono_volumen(nivel, silencio):
    return "audio-volume-muted-symbolic" if silencio or nivel == 0 else "audio-volume-high-symbolic"


def icono_bateria(d):
    nivel = "full" if d["capacidad"] >= 90 else "good" if d["capacidad"] >= 50 else \
        "low" if d["capacidad"] >= 20 else "caution"
    return f"battery-{nivel}-charging-symbolic" if d["estado"] == "cargando" else f"battery-{nivel}-symbolic"


class Mosaico(Gtk.Box):
    """Wi-Fi o Bluetooth: un botón que se queda pulsado mientras está encendido, con el nombre y lo que hace
    ahora debajo, y la flecha a lo demás. al_cambiar(activo): lo ha pulsado la persona, no poner()."""

    def __init__(self, icono, nombre, al_cambiar, al_flecha, ayuda_flecha):
        super().__init__(spacing=2)
        self.add_css_class("mosaico")
        self.al_cambiar = al_cambiar
        self.desde_fuera = False
        self.boton = Gtk.ToggleButton(hexpand=True)
        caja = Gtk.Box(spacing=12)
        self.icono = Gtk.Image.new_from_icon_name(icono)
        caja.append(self.icono)
        textos = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, valign=Gtk.Align.CENTER)
        self.nombre = Gtk.Label(label=nombre, xalign=0)
        textos.append(self.nombre)
        self.detalle = Gtk.Label(label=" ", xalign=0, ellipsize=Pango.EllipsizeMode.END, max_width_chars=26)
        self.detalle.add_css_class("tenue")
        textos.append(self.detalle)
        caja.append(textos)
        self.boton.set_child(caja)
        self.boton.connect("toggled", self.al_pulsar)
        self.append(self.boton)
        self.flecha = Gtk.Button(icon_name="go-next-symbolic", tooltip_text=ayuda_flecha)
        self.flecha.add_css_class("flecha")
        self.flecha.connect("clicked", lambda _b: al_flecha())
        self.append(self.flecha)

    def poner(self, activo, detalle, icono):
        self.desde_fuera = True
        self.boton.set_active(activo)
        self.desde_fuera = False
        self.detalle.set_text(detalle)
        self.icono.set_from_icon_name(icono)

    def al_pulsar(self, boton):
        if not self.desde_fuera:
            self.al_cambiar(boton.get_active())


class Panel:
    def __init__(self, app, pagina):
        self._ = _ = traductor()
        self.app = app
        self.v = Gtk.ApplicationWindow(application=app, title=_("centro de control"))
        self.v.set_decorated(False)
        self.v.set_resizable(False)
        self.v.add_css_class("centro")
        self.v.add_css_class(f"lado-{LADO}")
        escape_cierra(self.v)
        self.leyendo = False
        self.otra_vez = False
        self.cambiando = set()  # "wifi", "bt": encendiendo o apagando, el mosaico no se repinta
        self.activa = False
        self.cerrando = False
        self.redes = None
        self.pagina = None
        self.entra = 0
        self.v.connect("notify::is-active", self.al_foco)
        self.v.connect("close-request", self.al_cerrar)

        # El ancho no cambia con la página: la regla de labwc coloca la ventana una vez, por su esquina de
        # arriba a la izquierda, y si creciera hacia la derecha se saldría de la pantalla.
        self.pila = Gtk.Stack(hhomogeneous=True, vhomogeneous=False)
        self.pila.add_css_class("panel")
        self.pila.add_css_class("centro-panel")
        self.pila.set_size_request(ANCHO, -1)
        self.pila.add_named(self.inicio(), "inicio")
        self.v.set_child(self.pila)
        self.ir(pagina)
        self.leer()
        GLib.timeout_add_seconds(CADA, lambda: (self.leer(), True)[1])

    # ---- Páginas ----------------------------------------------------------------------------------

    def inicio(self):
        _ = self._
        caja = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.wifi = Mosaico("network-wireless-symbolic", _("wi-fi"), lambda a: self.encender("wifi", a),
                            lambda: self.ir("redes"), _("ver las redes wi-fi"))
        caja.append(self.wifi)
        self.bt = None
        if bt.adaptador():
            self.bt = Mosaico("bluetooth-symbolic", _("bluetooth"), lambda a: self.encender("bt", a),
                              lambda: self.abrir_ajustes("bluetooth"), _("dispositivos y más ajustes del bluetooth"))
            caja.append(self.bt)

        niveles = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        niveles.add_css_class("niveles")
        self.volumen = Deslizador("audio-volume-high-symbolic", 0, sonido.poner_volumen, self.silenciar)
        self.volumen.icono.set_tooltip_text(_("silenciar o volver a oír"))
        self.volumen.set_sensitive(False)
        niveles.append(self.volumen)
        self.brillo = None
        if sonido.hay_brillo():
            self.brillo = Deslizador("display-brightness-symbolic", sonido.BRILLO_MINIMO, sonido.poner_brillo,
                                     minimo=sonido.BRILLO_MINIMO)
            self.brillo.set_tooltip_text(_("brillo"))
            self.brillo.set_sensitive(False)
            niveles.append(self.brillo)
        caja.append(niveles)

        self.bateria = None
        if bateria.estado() is not None:  # solo lee /sys: no hace esperar
            self.bateria = Gtk.Button()
            self.bateria.add_css_class("flat")
            self.bateria.add_css_class("linea")
            self.bateria.set_tooltip_text(_("ajustes de la batería"))
            fila = Gtk.Box(spacing=12)
            self.icono_bateria = Gtk.Image.new_from_icon_name("battery-good-symbolic")
            fila.append(self.icono_bateria)
            self.texto_bateria = Gtk.Label(xalign=0, hexpand=True, ellipsize=Pango.EllipsizeMode.END)
            fila.append(self.texto_bateria)
            fila.append(Gtk.Label(label="›"))
            self.bateria.set_child(fila)
            self.bateria.connect("clicked", lambda _b: self.abrir_ajustes("bateria"))
            caja.append(self.bateria)

        pie = Gtk.Box(halign=Gtk.Align.END)
        pie.add_css_class("pie")
        ajustes = boton(_("ajustes"))
        ajustes.connect("clicked", lambda _b: self.abrir_ajustes(None))
        pie.append(ajustes)
        caja.append(pie)
        return caja

    def pagina_redes(self):
        _ = self._
        caja = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        cabecera = Gtk.Box(spacing=6)
        volver = Gtk.Button(icon_name="go-previous-symbolic", tooltip_text=_("volver"))
        volver.add_css_class("flat")
        volver.connect("clicked", lambda _b: self.ir("inicio"))
        cabecera.append(volver)
        titulo = Gtk.Label(label=_("redes wi-fi"), xalign=0)
        titulo.add_css_class("titulo")
        cabecera.append(titulo)
        caja.append(cabecera)
        self.redes = ListaRedes(_, completa=False, filas=6, al_cambiar=self.leer, fija=DESDE_ABAJO)
        caja.append(self.redes)
        mas = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        mas.add_css_class("avanzado")
        enlace = Gtk.Button(halign=Gtk.Align.START)
        enlace.add_css_class("flat")
        enlace.set_child(Gtk.Label(label=f"{_('todos los ajustes de red')}  ›", xalign=0))
        enlace.connect("clicked", lambda _b: self.abrir_ajustes("red"))
        mas.append(enlace)
        caja.append(mas)
        return caja

    def ir(self, pagina):
        if DESDE_ABAJO and self.pagina is not None and pagina != self.pagina:
            self.app.reabrir(pagina)
            return
        if pagina == "redes" and self.redes is None:
            self.pila.add_named(self.pagina_redes(), "redes")
        elif pagina == "redes" and self.pagina != "redes":
            self.redes.al_dia()  # el wi-fi se ha podido encender o apagar en la otra página
        self.pila.set_visible_child_name(pagina)
        if self.pagina is not None:
            # Al cambiar de página, entra como las secciones de Ajustes (command.css); al abrirse, el panel
            # entero ya entra con la suya.
            hijo = self.pila.get_visible_child()
            self.entra = 1 - self.entra
            hijo.remove_css_class("entra-a" if self.entra else "entra-b")
            hijo.add_css_class("entra-b" if self.entra else "entra-a")
        self.pagina = pagina

    # ---- Estado -----------------------------------------------------------------------------------

    def leer(self):
        if self.leyendo:
            self.otra_vez = True  # lo que se lee ahora puede ser de antes del cambio: otra lectura al acabar
            return

        def hecho(estado):
            self.leyendo = False
            self.pintar(estado)
            if self.otra_vez:
                self.otra_vez = False
                self.leer()
        self.leyendo = True
        en_hilo(leer_estado, hecho)

    def pintar(self, e):
        _ = self._
        conexion = e["conexion"]
        if conexion and conexion[0] == "wifi":
            detalle = conexion[1]
        elif conexion:
            detalle = _("por cable")
        elif e["hay_wifi"] and not e["wifi"]:
            detalle = _("apagado")
        else:
            detalle = _("sin red")
        if "wifi" not in self.cambiando:
            if e["hay_wifi"]:
                icono = "network-wireless-symbolic" if e["wifi"] else "network-wireless-offline-symbolic"
            else:
                icono = "network-wired-symbolic"
                self.wifi.nombre.set_text(_("red"))
            self.wifi.poner(e["wifi"], detalle, icono)
            # Sin tarjeta wi-fi solo informa de la red por cable: no se pulsa, pero se lee (sin atenuar).
            self.wifi.boton.set_can_target(e["hay_wifi"])
            self.wifi.boton.set_focusable(e["hay_wifi"])
            self.wifi.flecha.set_visible(e["hay_wifi"])

        if self.bt is not None and "bt" not in self.cambiando:
            nombres = e["bt_conectados"]
            if not e["bt"]:
                detalle = _("apagado")
            elif len(nombres) == 1:
                detalle = nombres[0]
            elif nombres:
                detalle = _("{n} dispositivos conectados").format(n=len(nombres))
            else:
                detalle = _("encendido")
            self.bt.poner(e["bt"], detalle, "bluetooth-symbolic" if e["bt"] else "bluetooth-disabled-symbolic")

        if e["volumen"] is not None and self.volumen.pendiente is None:
            self.volumen.set_sensitive(True)
            self.volumen.poner(e["volumen"][0], icono_volumen(*e["volumen"]))
        if self.brillo is not None and e["brillo"] is not None and self.brillo.pendiente is None:
            self.brillo.set_sensitive(True)
            self.brillo.poner(e["brillo"])
        if self.bateria is not None and e["bateria"] is not None:
            self.texto_bateria.set_text(bateria.resumen(e["bateria"], _))
            self.icono_bateria.set_from_icon_name(icono_bateria(e["bateria"]))

    def encender(self, que, activo):
        mosaico = self.wifi if que == "wifi" else self.bt
        self.cambiando.add(que)
        mosaico.boton.set_sensitive(False)

        def hecho(_resultado):
            self.cambiando.discard(que)
            mosaico.boton.set_sensitive(True)
            self.leer()
        en_hilo(lambda: red.poner_wifi(activo) if que == "wifi" else bt.poner(activo), hecho)

    def silenciar(self):
        v = sonido.volumen()
        if v is None:
            return
        sonido.silenciar(not v[1])
        v = sonido.volumen() or v
        self.volumen.poner(v[0], icono_volumen(*v))

    # ---- Abrir y cerrar ---------------------------------------------------------------------------

    def abrir_ajustes(self, seccion):
        lanzar(["command-os-ajustes", *([seccion] if seccion else [])])
        self.v.close()

    def al_foco(self, ventana, _param):
        if ventana.is_active():
            self.activa = True
        elif self.activa and not self.cerrando:
            apuntar_cierre()
            ventana.close()

    def al_cerrar(self, _ventana):
        self.cerrando = True
        return False


class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id=IDS[LADO], flags=Gio.ApplicationFlags.HANDLES_COMMAND_LINE)
        self.panel = None

    def do_command_line(self, linea):
        args = linea.get_arguments()[1:]
        pagina = "redes" if args[:1] == ["redes"] else "inicio"
        if self.panel is None or self.panel.cerrando:
            if cerrado_hace_poco():
                return 0
            cargar_tema()
            self.panel = Panel(self, pagina)
            self.panel.v.present()
        elif self.panel.pagina == pagina:
            self.panel.v.close()  # otro clic en la barra: se cierra
        else:
            self.panel.ir(pagina)
            self.panel.v.present()
        return 0

    def reabrir(self, pagina):
        """Cambia de página abriendo otro panel (colgado de abajo): la regla de labwc lo coloca al abrirse."""
        viejo = self.panel
        viejo.cerrando = True  # pierde el foco por el nuevo: que no apunte un cierre
        self.panel = Panel(self, pagina)
        self.panel.v.present()
        viejo.v.close()


if __name__ == "__main__":
    sys.exit(App().run(sys.argv))
