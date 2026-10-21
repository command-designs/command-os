# Command OS — la lista de redes wi-fi (GTK 4) que comparten Ajustes → wi-fi y red y el centro de
# control: el interruptor del wi-fi, las redes (la conectada primero, luego por señal, con candado si
# piden contraseña) y la conexión en dos pasos, la red y después, si hace falta, la contraseña, en la
# misma ventana. Toda la red pasa por lib/red.py (nmcli) en un hilo: la ventana no se bloquea.
import red
from comun import boton, en_hilo, interruptor
from gi.repository import GLib, Gtk, Pango

ICONOS = ["network-wireless-signal-none-symbolic", "network-wireless-signal-weak-symbolic",
          "network-wireless-signal-ok-symbolic", "network-wireless-signal-good-symbolic",
          "network-wireless-signal-excellent-symbolic"]


class ListaRedes(Gtk.Box):
    """completa: también «olvidar» las guardadas (Ajustes); en el centro de control, solo conectar.
    filas: cuántas redes caben sin desplazar. al_cambiar(): tras conectar o desconectar."""

    def __init__(self, traducir, completa=True, filas=8, al_cambiar=None):
        super().__init__(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self._ = _ = traducir
        self.completa = completa
        self.al_cambiar = al_cambiar or (lambda: None)
        self.ocupado = False
        self.sincronizando = False
        self.red_clave = None
        self.dispositivo = red.dispositivo_wifi()

        if self.dispositivo is None:
            nota = Gtk.Label(label=_("este equipo no tiene wi-fi."), xalign=0)
            nota.add_css_class("tenue")
            self.append(nota)
            return

        fila, self.switch = interruptor(_("wi-fi"), red.wifi_encendido(), self.al_interruptor)
        self.append(fila)

        self.pila = Gtk.Stack()
        self.append(self.pila)

        # Paso 1: las redes.
        lista = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        cabecera = Gtk.Box(spacing=8)
        self.estado = Gtk.Label(xalign=0, hexpand=True, wrap=True, max_width_chars=40)
        self.estado.add_css_class("tenue")
        cabecera.append(self.estado)
        self.buscar = Gtk.Button(icon_name="view-refresh-symbolic", tooltip_text=_("buscar redes otra vez"))
        self.buscar.add_css_class("flat")
        self.buscar.connect("clicked", lambda _b: self.refrescar(buscar=True))
        cabecera.append(self.buscar)
        lista.append(cabecera)
        self.filas = Gtk.ListBox(selection_mode=Gtk.SelectionMode.NONE, activate_on_single_click=True)
        self.filas.add_css_class("redes")
        self.filas.connect("row-activated", lambda _l, f: self.elegir(f.red))
        desliza = Gtk.ScrolledWindow(hscrollbar_policy=Gtk.PolicyType.NEVER, propagate_natural_height=True,
                                     max_content_height=filas * 48)
        desliza.set_child(self.filas)
        lista.append(desliza)
        self.pila.add_named(lista, "lista")

        # Paso 2: la contraseña.
        paso = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        self.titulo_clave = Gtk.Label(xalign=0, wrap=True, max_width_chars=40)
        self.titulo_clave.add_css_class("dato")
        paso.append(self.titulo_clave)
        self.clave = Gtk.PasswordEntry(show_peek_icon=True)
        self.clave.connect("activate", lambda _e: self.conectar_con_clave())
        paso.append(self.clave)
        self.error_clave = Gtk.Label(xalign=0, wrap=True, max_width_chars=40)
        self.error_clave.add_css_class("error")
        paso.append(self.error_clave)
        botones = Gtk.Box(spacing=10, halign=Gtk.Align.END)
        cancelar = boton(_("cancelar"))
        cancelar.add_css_class("flat")
        cancelar.connect("clicked", lambda _b: self.volver())
        botones.append(cancelar)
        self.boton_conectar = boton(_("conectar"))
        self.boton_conectar.add_css_class("suggested-action")
        self.boton_conectar.connect("clicked", lambda _b: self.conectar_con_clave())
        botones.append(self.boton_conectar)
        paso.append(botones)
        self.pila.add_named(paso, "clave")

        self.refrescar()

    # ---- Lista -----------------------------------------------------------------------------------

    def avisar(self, texto, error=False):
        self.estado.remove_css_class("tenue" if error else "error")
        self.estado.add_css_class("error" if error else "tenue")
        self.estado.set_text(texto)

    def refrescar(self, buscar=False, aviso=None):
        if self.dispositivo is None or self.ocupado:
            return
        if not self.switch.get_active():
            self.pintar([])
            self.avisar(self._("el wi-fi está apagado."))
            return
        self.ocupado = True
        self.buscar.set_sensitive(False)
        if aviso is None:
            self.avisar(self._("buscando redes…"))

        def hecho(lista):
            self.ocupado = False
            self.buscar.set_sensitive(True)
            self.pintar(lista)
            if aviso is not None:
                self.avisar(*aviso)
            else:
                self.avisar("" if lista else self._("no se ve ninguna red wi-fi."))
        en_hilo(lambda: red.redes(buscar), hecho)

    def pintar(self, lista):
        while (hijo := self.filas.get_first_child()) is not None:
            self.filas.remove(hijo)
        for r in lista:
            self.filas.append(self.fila(r))

    def fila(self, r):
        _ = self._
        f = Gtk.ListBoxRow()
        f.red = r
        caja = Gtk.Box(spacing=12)
        caja.append(Gtk.Image.new_from_icon_name(ICONOS[red.senal_nivel(r["senal"])]))
        textos = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, hexpand=True, valign=Gtk.Align.CENTER)
        textos.append(Gtk.Label(label=r["nombre"], xalign=0, ellipsize=Pango.EllipsizeMode.END))
        detalle = _("conectada") if r["conectada"] else _("guardada") if r["guardada"] else ""
        if detalle:
            d = Gtk.Label(label=detalle, xalign=0)
            d.add_css_class("tenue")
            textos.append(d)
        caja.append(textos)
        if r["segura"]:
            candado = Gtk.Image.new_from_icon_name("network-wireless-encrypted-symbolic")
            candado.set_tooltip_text(_("pide contraseña"))
            candado.add_css_class("tenue")
            caja.append(candado)
        if r["conectada"]:
            b = boton(_("desconectar"), valign=Gtk.Align.CENTER)
            b.add_css_class("flat")
            b.connect("clicked", lambda _b: self.desconectar(r))
            caja.append(b)
        elif r["guardada"] and self.completa:
            b = boton(_("olvidar"), valign=Gtk.Align.CENTER)
            b.add_css_class("flat")
            b.set_tooltip_text(_("borra la red guardada y su contraseña"))
            b.connect("clicked", lambda _b: self.olvidar(r))
            caja.append(b)
        f.set_child(caja)
        return f

    # ---- Conectar ----------------------------------------------------------------------------------

    def elegir(self, r):
        if r["conectada"] or self.ocupado:
            return
        self.conectar(r, None)

    def conectar(self, r, clave):
        _ = self._
        self.ocupado = True
        self.boton_conectar.set_sensitive(False)
        self.avisar(_("conectando a {red}…").format(red=r["nombre"]))
        self.error_clave.set_text(_("conectando…") if clave is not None else "")

        def hecho(codigo):
            self.ocupado = False
            self.boton_conectar.set_sensitive(True)
            if codigo is None:
                self.volver(refrescar=False)
                self.refrescar(aviso=(_("conectada a {red}.").format(red=r["nombre"]),))
                self.al_cambiar()
            elif codigo == "necesita_clave" or (codigo == "fallo" and clave is not None):
                self.pedir_clave(r, _("no se pudo conectar: revisa la contraseña.") if clave is not None else "")
            else:
                self.avisar(_("no se pudo conectar a {red}.").format(red=r["nombre"]), error=True)
        en_hilo(lambda: red.conectar(r, clave), hecho)

    def pedir_clave(self, r, error=""):
        self.red_clave = r
        self.titulo_clave.set_text(self._("contraseña de «{red}»").format(red=r["nombre"]))
        self.error_clave.set_text(error)
        self.clave.set_text("")
        self.pila.set_visible_child_name("clave")
        self.clave.grab_focus()

    def conectar_con_clave(self):
        clave = self.clave.get_text()
        if self.red_clave is None or self.ocupado:
            return
        if len(clave) < 8 and "WPA" in self.red_clave.get("seguridad", ""):
            # WPA no admite menos de 8 (WEP sí); así no se espera a nmcli para saberlo.
            self.error_clave.set_text(self._("la contraseña de una red wi-fi tiene al menos 8 caracteres."))
            return
        self.conectar(self.red_clave, clave)

    def volver(self, refrescar=True):
        self.red_clave = None
        self.clave.set_text("")
        self.error_clave.set_text("")
        self.pila.set_visible_child_name("lista")
        if refrescar:
            self.avisar("")

    def desconectar(self, r):
        _ = self._
        if self.ocupado:
            return

        def hecho(bien):
            self.refrescar(aviso=(_("desconectada de {red}.").format(red=r["nombre"]),) if bien
                           else (_("no se pudo desconectar."), True))
            self.al_cambiar()
        en_hilo(red.desconectar, hecho)

    def olvidar(self, r):
        _ = self._
        if self.ocupado:
            return

        def hecho(bien):
            self.refrescar(aviso=(_("{red} olvidada.").format(red=r["nombre"]),) if bien
                           else (_("no se pudo olvidar la red."), True))
        en_hilo(lambda: red.olvidar(r["nombre"]), hecho)

    # ---- Encender y apagar ---------------------------------------------------------------------------

    def al_dia(self):
        """Al volver a la lista: el wi-fi se ha podido encender o apagar fuera (el centro de control, la
        barra), así que se vuelve a mirar antes de buscar redes."""
        if self.dispositivo is None:
            return
        encendido = red.wifi_encendido()
        if encendido != self.switch.get_active():
            self.sincronizando = True
            self.switch.set_active(encendido)
            self.sincronizando = False
        self.refrescar()

    def al_interruptor(self, switch, activo):
        if self.sincronizando:
            return False  # lo pone al_dia(): solo se pinta

        def hecho(bien):
            switch.set_state(activo if bien else not activo)
            if activo and bien:
                # La tarjeta tarda unos segundos en ver las redes al encenderse.
                self.avisar(self._("buscando redes…"))
                GLib.timeout_add_seconds(3, lambda: (self.refrescar(), False)[1])
            else:
                self.refrescar()
            self.al_cambiar()
        en_hilo(lambda: red.poner_wifi(activo), hecho)
        return True
