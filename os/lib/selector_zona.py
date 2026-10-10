# Command OS — selector de zona horaria (GTK 4): un botón con la zona elegida que abre un desplegable
# con buscador. Se busca por ciudad, país (en el idioma de la ventana) o nombre de la zona, sin tildes.
# Lo usan el asistente de primer arranque (lib/primer-arranque.py) y el panel de cuentas
# (lib/panel-cuentas.py). Las zonas y su búsqueda están en lib/zonas.py.
import zonas
from gi.repository import GLib, Gtk, Pango


class SelectorZona(Gtk.MenuButton):
    def __init__(self, catalogo, traducir, zona, al_elegir, pared=None):
        """catalogo: zonas.catalogo(idioma, traducir). al_elegir(zona): se llama al elegir una.
        pared: la zona cuya hora de pared es la de todas (reloj del equipo en hora local, sin red)."""
        super().__init__(hexpand=True)
        self._ = _ = traducir
        self.zona = zona
        self.pared = pared
        self.al_elegir = al_elegir
        self.texto_zona = Gtk.Label(xalign=0, hexpand=True, ellipsize=Pango.EllipsizeMode.END)
        self.set_child(self.texto_zona)

        caja = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=8)
        self.buscar = Gtk.SearchEntry(placeholder_text=_("busca tu ciudad o tu país"))
        self.buscar.connect("search-changed", lambda _e: self.lista_zonas.invalidate_filter())
        self.buscar.connect("activate", self.on_buscar_intro)
        caja.append(self.buscar)

        self.lista_zonas = Gtk.ListBox(selection_mode=Gtk.SelectionMode.SINGLE)
        self.lista_zonas.add_css_class("zonas")
        nada = Gtk.Label(label=_("sin resultados"), margin_top=12)
        nada.add_css_class("tenue")
        self.lista_zonas.set_placeholder(nada)
        self.filas_zona = {}
        for z in catalogo:
            fila_zona = Gtk.ListBoxRow()
            fila_zona.zona = z
            linea = Gtk.Box(spacing=12)
            linea.append(Gtk.Label(label=f"{z.ciudad} · {z.pais}", xalign=0, hexpand=True,
                                   ellipsize=Pango.EllipsizeMode.END))
            fila_zona.desfase = Gtk.Label(xalign=1)
            fila_zona.desfase.add_css_class("desfase")
            linea.append(fila_zona.desfase)
            fila_zona.set_child(linea)
            self.lista_zonas.append(fila_zona)
            self.filas_zona[z.zona] = fila_zona
        self.lista_zonas.set_filter_func(lambda f: f.zona.coincide(self.buscar.get_text()))
        self.lista_zonas.connect("row-activated", self.on_zona)
        # Tamaño fijo: con el de la lista, las etiquetas recortadas lo dejarían estrecho.
        desliza = Gtk.ScrolledWindow(hscrollbar_policy=Gtk.PolicyType.NEVER)
        desliza.set_size_request(420, 300)
        desliza.set_child(self.lista_zonas)
        caja.append(desliza)

        popover = Gtk.Popover(child=caja)
        popover.connect("show", self.on_abrir_zonas)
        self.set_popover(popover)
        self.poner_hora()

    def poner_zona(self, zona):
        """Cambia la zona que enseña el botón, sin avisar a al_elegir."""
        self.zona = zona
        self.poner_hora()

    def texto_de_zona(self, zona):
        """«UTC+2 · 14:32»."""
        hora = zonas.hora(zona, self.pared)
        return " · ".join(p for p in (zonas.diferencia(zona), hora) if p)

    def poner_hora(self):
        fila_zona = self.filas_zona.get(self.zona)
        nombre = f"{fila_zona.zona.ciudad} · {fila_zona.zona.pais}" if fila_zona else self.zona
        self.texto_zona.set_text(f"{nombre} — {self.texto_de_zona(self.zona)}")
        return True  # cada 20 s, para que la hora del botón no se quede atrás

    def on_abrir_zonas(self, _popover):
        for zona, fila_zona in self.filas_zona.items():
            fila_zona.desfase.set_text(self.texto_de_zona(zona))
        self.buscar.set_text("")
        elegida = self.filas_zona.get(self.zona)
        if elegida:
            self.lista_zonas.select_row(elegida)
        GLib.idle_add(self.enfocar_zona, elegida)

    def enfocar_zona(self, elegida):
        """Lleva la lista hasta la zona elegida y deja el cursor en el buscador. Al terminar de
        abrirse el desplegable: antes, la lista no tiene tamaño para desplazarse."""
        if elegida:
            elegida.grab_focus()
        self.buscar.grab_focus()
        return False

    def on_buscar_intro(self, _entrada):
        """Intro en el buscador elige la primera zona que se ve."""
        fila_zona = self.lista_zonas.get_first_child()
        while fila_zona is not None and not fila_zona.get_child_visible():
            fila_zona = fila_zona.get_next_sibling()
        if isinstance(fila_zona, Gtk.ListBoxRow):
            self.on_zona(self.lista_zonas, fila_zona)

    def on_zona(self, _lista, fila_zona):
        self.zona = fila_zona.zona.zona
        self.poner_hora()
        self.popdown()
        self.al_elegir(self.zona)
