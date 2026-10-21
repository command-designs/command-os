# Command OS — Ajustes → bluetooth (lib/ajustes.py; solo sale con adaptador). Encender o apagar (apagado de
# serie) y los dispositivos emparejados: conectar, desconectar y olvidar (lib/bt.py). Emparejar
# uno nuevo, en «avanzado» (blueman: su applet ya es el agente que contesta al PIN).
# docs/notas/escritorio.md § «Bluetooth».
import bt
from comun import Seccion, boton, interruptor
from gi.repository import Gtk, Pango


class Pagina(Seccion):
    def __init__(self, ventana, traducir):
        super().__init__(ventana, traducir)
        _ = self._
        self.ocupado = False
        self.titulo(_("› bluetooth"))
        fila, self.switch = interruptor(_("bluetooth"), bt.encendido(), self.al_interruptor,
                                        _("apagado de serie; se apaga también al reiniciar."))
        self.caja.append(fila)
        self.etiqueta(_("dispositivos emparejados"))
        self.lista = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        self.caja.append(self.lista)
        self.estado = self.nota("")
        self.avanzado([(_("emparejar un dispositivo nuevo"), ["blueman-manager"])])
        self.pintar()
        self.cada(10, self.pintar)

    def al_mostrar(self):
        self.switch.set_state(bt.encendido())
        self.pintar()

    def pintar(self):
        if self.ocupado:
            return
        _ = self._
        while (hijo := self.lista.get_first_child()) is not None:
            self.lista.remove(hijo)
        if not self.switch.get_active():
            self.estado.set_text(_("enciende el bluetooth para ver y conectar los dispositivos."))
            return

        def hecho(lista):
            while (hijo := self.lista.get_first_child()) is not None:
                self.lista.remove(hijo)
            for d in lista:
                self.lista.append(self.fila(d))
            self.estado.set_text("" if lista else _("no hay dispositivos emparejados: empareja uno en «avanzado»."))
        self.en_hilo(bt.dispositivos, hecho)

    def fila(self, d):
        _ = self._
        caja = Gtk.Box(spacing=12)
        caja.append(Gtk.Image.new_from_icon_name(f"{d['icono']}-symbolic"))
        textos = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, hexpand=True, valign=Gtk.Align.CENTER)
        textos.append(Gtk.Label(label=d["nombre"], xalign=0, ellipsize=Pango.EllipsizeMode.END))
        detalle = Gtk.Label(label=_("conectado") if d["conectado"] else _("sin conectar"), xalign=0)
        detalle.add_css_class("tenue")
        textos.append(detalle)
        caja.append(textos)
        if d["conectado"]:
            b = boton(_("desconectar"), valign=Gtk.Align.CENTER)
            b.connect("clicked", lambda _b: self.hacer("disconnect", d))
        else:
            b = boton(_("conectar"), valign=Gtk.Align.CENTER)
            b.connect("clicked", lambda _b: self.hacer("connect", d))
        b.add_css_class("flat")
        caja.append(b)
        olvidar = boton(_("olvidar"), valign=Gtk.Align.CENTER)
        olvidar.add_css_class("flat")
        olvidar.connect("clicked", lambda _b: self.hacer("remove", d))
        caja.append(olvidar)
        return caja

    def hacer(self, orden, d):
        _ = self._
        if self.ocupado:
            return
        self.ocupado = True
        textos = {
            "connect": (_("conectando {disp}…"), _("no se pudo conectar {disp}: ¿está encendido y cerca?")),
            "disconnect": (_("desconectando {disp}…"), _("no se pudo desconectar {disp}.")),
            "remove": (_("olvidando {disp}…"), _("no se pudo olvidar {disp}.")),
        }
        mientras, fallo = textos[orden]
        self.estado.set_text(mientras.format(disp=d["nombre"]))

        def hecho(bien):
            self.ocupado = False
            self.pintar()
            if not bien:
                self.estado.set_text(fallo.format(disp=d["nombre"]))
        self.en_hilo(lambda: bt.accion(orden, d["mac"]), hecho)

    def al_interruptor(self, switch, activo):
        def hecho(bien):
            switch.set_state(activo if bien else not activo)
            self.pintar()
        self.en_hilo(lambda: bt.poner(activo), hecho)
        return True
