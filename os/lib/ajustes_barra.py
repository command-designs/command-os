# Command OS — Ajustes → barra (lib/ajustes.py). El lado de la pantalla y si va flotante, la telemetría
# (CPU, temperatura y memoria: oculta de serie, es lo único de la barra que se despierta solo) y las
# aplicaciones fijadas: quitar, cambiar de sitio y fijar otra (lib/fijadas.py, lo mismo que el clic
# derecho en la barra).
# docs/notas/escritorio.md §§ «Barra» y «Aplicaciones fijadas».
import os

import fijadas
from comun import Seccion, boton, fila, interruptor
from gi.repository import Gtk, Pango


class Pagina(Seccion):
    def __init__(self, ventana, traducir):
        super().__init__(ventana, traducir)
        _ = self._
        self.titulo(_("› barra"))
        self.lados = list(fijadas.LADOS)
        nombres = {"arriba": _("arriba"), "abajo": _("abajo"), "izquierda": _("izquierda"), "derecha": _("derecha")}
        self.combo = Gtk.DropDown.new_from_strings([nombres[lado] for lado in self.lados])
        self.pintado = self.lados.index(fijadas.ajustes()["lado"])
        self.combo.set_selected(self.pintado)
        self.combo.connect("notify::selected", self.al_lado)
        self.caja.append(fila(_("lado de la pantalla"), self.combo))
        caja, self.switch_flotante = interruptor(
            _("flotante"), fijadas.ajustes()["flotante"] == "si", self.al_flotante,
            _("separada de los bordes, con aire alrededor."))
        self.caja.append(caja)
        caja, self.switch = interruptor(
            _("cpu, temperatura y memoria"), fijadas.ajustes()["telemetria"] == "si", self.al_telemetria,
            _("se ponen al día cada 10 segundos. ocultas, la barra no gasta nada en reposo."))
        self.caja.append(caja)
        cabecera = Gtk.Box(spacing=12)
        rotulo = Gtk.Label(label=_("aplicaciones fijadas").upper(), xalign=0, hexpand=True)
        rotulo.add_css_class("etiqueta")
        cabecera.append(rotulo)
        fijar = boton(_("fijar otra"))
        fijar.connect("clicked", self.al_fijar)
        cabecera.append(fijar)
        self.caja.append(cabecera)
        self.lista = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
        self.caja.append(self.lista)
        self.pintar()

    def al_mostrar(self):
        valores = fijadas.ajustes()
        self.pintado = self.lados.index(valores["lado"])
        self.combo.set_selected(self.pintado)
        self.switch_flotante.set_state(valores["flotante"] == "si")
        self.switch.set_state(valores["telemetria"] == "si")
        self.pintar()

    def pintar(self):
        _ = self._
        while (hijo := self.lista.get_first_child()) is not None:
            self.lista.remove(hijo)
        ids = fijadas.lista()
        if not ids:
            nota = Gtk.Label(label=_("ninguna: fija una con «fijar otra» o con el clic derecho en el logo de la barra."),
                             xalign=0, wrap=True, max_width_chars=60)
            nota.add_css_class("tenue")
            self.lista.append(nota)
        for i, ident in enumerate(ids):
            entrada = fijadas.leer_desktop(fijadas.ruta_desktop(ident))
            caja = Gtk.Box(spacing=12)
            icono = entrada.get("Icon", "")
            imagen = Gtk.Image.new_from_file(icono) if os.path.isabs(icono) else Gtk.Image.new_from_icon_name(
                icono or "application-x-executable")
            imagen.set_pixel_size(24)
            caja.append(imagen)
            caja.append(Gtk.Label(label=fijadas.nombre(entrada, ident), xalign=0, hexpand=True,
                                  ellipsize=Pango.EllipsizeMode.END))
            for icono_b, texto, paso, activo in (("go-previous-symbolic", _("más a la izquierda"), -1, i > 0),
                                                  ("go-next-symbolic", _("más a la derecha"), 1, i < len(ids) - 1)):
                b = Gtk.Button(icon_name=icono_b, tooltip_text=texto, sensitive=activo)
                b.add_css_class("flat")
                b.connect("clicked", lambda _b, x=ident, p=paso: (fijadas.mover(x, p), self.pintar()))
                caja.append(b)
            quitar = boton(_("quitar"), valign=Gtk.Align.CENTER)
            quitar.add_css_class("flat")
            quitar.connect("clicked", lambda _b, x=ident: (fijadas.quitar(x), self.pintar()))
            caja.append(quitar)
            self.lista.append(caja)

    def al_fijar(self, _boton):
        # El lanzador de siempre, pero fija en vez de abrir; espera a que se elija (en un hilo).
        self.en_hilo(fijadas.fijar, lambda _r: self.pintar())

    def al_lado(self, combo, _param):
        i = combo.get_selected()
        if i == self.pintado:
            return
        self.pintado = i
        self.en_hilo(lambda: fijadas.poner("lado", self.lados[i]), lambda _r: None)

    def al_flotante(self, switch, activo):
        self.en_hilo(lambda: fijadas.poner("flotante", "si" if activo else "no"),
                     lambda valor: switch.set_state(valor == "si"))
        return True

    def al_telemetria(self, switch, activo):
        def hecho(valor):
            switch.set_state(valor == "si")
        self.en_hilo(lambda: fijadas.telemetria("si" if activo else "no"), hecho)
        return True
