# Command OS — Ajustes → sonido (lib/ajustes.py). Salida y entrada: el dispositivo, el volumen y el
# silencio (lib/sonido.py: pamixer y pactl). El volumen de cada aplicación y los perfiles de las tarjetas,
# en «avanzado» (pavucontrol).
import sonido
from comun import Deslizador, Seccion, fila
from gi.repository import Gtk


class Lado:
    """La salida o la entrada: el desplegable de dispositivos y el volumen."""

    def __init__(self, seccion, entrada):
        _ = seccion._
        self.entrada = entrada
        self.nombres = []
        self.combo = Gtk.DropDown.new_from_strings([])
        self.combo.connect("notify::selected", self.al_dispositivo)
        self.pintado = None
        seccion.caja.append(fila(_("micrófono") if entrada else _("altavoces o auriculares"), self.combo))
        v = sonido.volumen(entrada) or (0, False)
        self.nivel = Deslizador(self.icono(*v), v[0], lambda n: sonido.poner_volumen(n, entrada), self.al_silencio)
        self.nivel.icono.set_tooltip_text(_("silenciar o volver a oír"))
        seccion.caja.append(self.nivel)
        self.al_dia()

    def icono(self, nivel, silencio):
        if self.entrada:
            return "microphone-sensitivity-muted-symbolic" if silencio else "audio-input-microphone-symbolic"
        return "audio-volume-muted-symbolic" if silencio or nivel == 0 else "audio-volume-high-symbolic"

    def al_dia(self):
        """Lo pone al día con lo de fuera (teclas de volumen, otro dispositivo enchufado)."""
        lista, serie = sonido.dispositivos(self.entrada)
        if [n for n, _d in lista] != self.nombres:
            self.nombres = [n for n, _d in lista]
            self.pintado = None
            self.combo.set_model(Gtk.StringList.new([d for _n, d in lista]))
        if serie in self.nombres and self.combo.get_selected() != self.nombres.index(serie):
            self.pintado = self.nombres.index(serie)
            self.combo.set_selected(self.pintado)
        v = sonido.volumen(self.entrada)
        if v is not None and self.nivel.pendiente is None:
            self.nivel.poner(v[0], self.icono(*v))

    def al_dispositivo(self, combo, _param):
        i = combo.get_selected()
        if i == self.pintado or i >= len(self.nombres):
            return
        self.pintado = i
        sonido.poner_dispositivo(self.nombres[i], self.entrada)
        self.al_dia()

    def al_silencio(self):
        v = sonido.volumen(self.entrada)
        if v is not None:
            sonido.silenciar(not v[1], self.entrada)
        self.al_dia()


class Pagina(Seccion):
    def __init__(self, ventana, traducir):
        super().__init__(ventana, traducir)
        _ = self._
        self.titulo(_("› sonido"))
        if sonido.volumen() is None:
            self.nota(_("no se encuentra ningún dispositivo de sonido."))
            self.lados = []
        else:
            self.lados = [Lado(self, False)]
            if sonido.dispositivos(True)[0]:
                self.lados.append(Lado(self, True))
        self.avanzado([(_("volumen de cada aplicación y perfiles de las tarjetas"), ["pavucontrol"])])
        self.cada(3, self.al_dia)

    def al_mostrar(self):
        self.al_dia()

    def al_dia(self):
        for lado in self.lados:
            lado.al_dia()
