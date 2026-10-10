#!/usr/bin/env python3
# Command OS — asistente de primer arranque (ventana GTK 4 a pantalla completa dentro de cage, como
# root). Pide idioma, teclado, zona horaria, nombre, usuario y contraseña, y si se entra solo al
# encender; crea la cuenta con /usr/lib/command-os/crear-cuenta (la contraseña va por la entrada
# estándar, nunca en argumentos ni registros), que también aplica el idioma y la zona. Lo lanza
# command-os-primer-arranque.
#
# El idioma cambia la ventana al momento; idioma y zona se aplican al sistema al crear la cuenta
# (antes no se toca nada). Se recuerdan en $XDG_RUNTIME_DIR por si se cambia el teclado, que reabre
# cage. Un teclado de un país con una sola zona la propone, si no se ha elegido otra a mano.
#
# Códigos de salida: 0 cuenta creada · 3 cambio de teclado (el lanzador vuelve a abrir cage con la
# distribución nueva, para que lo que se escriba ya salga con ella).
import os
import re
import subprocess
import sys
import threading
import unicodedata

import zonas
from comun import CONF, cargar_tema, disco_cifrado, fila, leer, logo, panel, traductor
from gi.repository import GLib, Gtk, Pango

CREAR = "/usr/lib/command-os/crear-cuenta"
MIN_CONTRASENA = 8
# Ancho máximo (en caracteres) de los textos largos: sin él, una traducción más larga ensancha el panel.
TEXTO_MAX = 50
RUNTIME = os.environ.get("XDG_RUNTIME_DIR", "/run/command-os-primer-arranque")
ELEGIDO = os.path.join(RUNTIME, "idioma")
ZONA = os.path.join(RUNTIME, "zona")
# Existe si la zona se eligió a mano: entonces el teclado ya no la cambia.
ZONA_TOCADA = os.path.join(RUNTIME, "zona-tocada")


def N_(texto):
    """Marca un texto para traducir sin traducirlo aún (se traduce al pintar la ventana)."""
    return texto


TECLADOS = [
    ("es", N_("español (España)")),
    ("latam", N_("español (Latinoamérica)")),
    ("us", N_("inglés (EE. UU.)")),
    ("gb", N_("inglés (Reino Unido)")),
    ("pt", N_("portugués (Portugal)")),
    ("br", N_("portugués (Brasil)")),
    ("fr", N_("francés")),
    ("de", N_("alemán")),
    ("it", N_("italiano")),
]


def idiomas():
    """[(locale, nombre en su idioma)] de command-os-idioma: la lista vive en un solo sitio."""
    try:
        r = subprocess.run(["command-os-idioma", "lista"], capture_output=True, text=True, check=True)
        lista = [tuple(linea.split(" ", 1)) for linea in r.stdout.splitlines() if " " in linea]
    except (OSError, subprocess.CalledProcessError):
        lista = []
    return lista or [("es_ES.UTF-8", "español")]


def idioma_inicial(lista):
    """El elegido antes de reabrir cage o, si no, el del sistema (LANG); si no está, el primero."""
    for pedido in (leer(ELEGIDO), os.environ.get("LANG", "")):
        base = pedido.split(".")[0]
        for codigo, _nombre in lista:
            if base and codigo.split(".")[0] == base:
                return codigo
    return lista[0][0]


def guardar(ruta, texto):
    try:
        with open(ruta, "w", encoding="utf-8") as f:
            f.write(texto + "\n")
    except OSError:
        pass  # solo se perdería al cambiar de teclado


def usuario_desde(nombre):
    """«Daniel Infante» -> «daniel»: primera palabra, sin tildes, en minúsculas."""
    plano = unicodedata.normalize("NFKD", nombre).encode("ascii", "ignore").decode()
    palabra = (plano.lower().split() or [""])[0]
    return re.sub(r"[^a-z0-9_-]", "", palabra)[:32]


class Asistente(Gtk.ApplicationWindow):
    def __init__(self, app):
        super().__init__(application=app)
        self.usuario_tocado = False
        self.teclado = leer(f"{CONF}/kb_layout", "es")
        self.idiomas = idiomas()
        self.idioma = idioma_inicial(self.idiomas)
        # Si el instalador dejó otra distribución (us-intl, de(nodeadkeys)…), sale la primera y
        # seleccionada: la lista nunca enseña un teclado distinto del que se está usando.
        self.teclados = list(TECLADOS)
        if self.teclado not in [c for c, _n in self.teclados]:
            self.teclados.insert(0, (self.teclado, None))
        # Zona: la elegida antes de reabrir cage o la que dejó el instalador (/etc/localtime).
        validas = {z for z, _c in zonas.zonas()}
        de_antes = zonas.actual()
        self.zona = next((z for z in (leer(ZONA), de_antes) if z in validas), "UTC")
        # Con el reloj del equipo en hora local y sin hora de la red, la hora de pared es la misma
        # en todas las zonas: la de la zona de antes (zonas.hora). Se mira una vez: el asistente
        # dura poco y la zona no cambia hasta crear la cuenta.
        self.pared = de_antes if zonas.reloj_local() and not zonas.sincronizada() else None
        self.catalogos = {}
        self.construir()
        GLib.timeout_add_seconds(20, self.poner_hora)
        self.nombre.grab_focus()

    def construir(self, valores=None):
        """Pinta la ventana en self.idioma. Con valores (de un cambio de idioma), los conserva."""
        _ = self._ = traductor(self.idioma)
        self.set_title(_("cmd-os · primer arranque"))
        fondo, caja = panel(460)
        marca = logo(44)
        if marca:
            caja.append(marca)

        titulo = Gtk.Label(label=_("› primer arranque"), xalign=0)
        titulo.add_css_class("titulo")
        caja.append(titulo)
        intro = Gtk.Label(
            label=_("crea la cuenta con la que vas a usar este equipo."), xalign=0, wrap=True,
            max_width_chars=TEXTO_MAX,
        )
        intro.add_css_class("tenue")
        caja.append(intro)

        # Idioma y teclado: lo primero, para que el resto ya salga en ese idioma y se escriba con él.
        # En la misma fila: el asistente cabe entero en pantallas de 720 px de alto.
        idioma_teclado = Gtk.Box(spacing=12, homogeneous=True)
        self.combo_idioma = Gtk.DropDown.new_from_strings([n for _c, n in self.idiomas])
        self.combo_idioma.set_selected([c for c, _n in self.idiomas].index(self.idioma))
        self.combo_idioma.connect("notify::selected", self.on_idioma)
        idioma_teclado.append(fila(_("idioma"), self.combo_idioma))

        nombres = [
            _(n) if n else _("{teclado} (del instalador)").format(teclado=c) for c, n in self.teclados
        ]
        self.combo = Gtk.DropDown.new_from_strings(nombres)
        self.combo.set_selected([c for c, _n in self.teclados].index(self.teclado))
        self.combo.connect("notify::selected", self.on_teclado)
        idioma_teclado.append(fila(_("teclado"), self.combo))
        caja.append(idioma_teclado)
        caja.append(fila(_("zona horaria"), self.construir_zona()))

        self.nombre = Gtk.Entry(placeholder_text=_("opcional"))
        self.nombre.connect("changed", self.on_nombre)
        self.usuario = Gtk.Entry(placeholder_text=_("minúsculas, sin espacios"))
        self.usuario.connect("changed", self.on_usuario)
        # Nombre y usuario en la misma fila, como idioma y teclado: con la zona horaria, el asistente
        # tiene que seguir cabiendo entero en 720 px de alto.
        nombre_usuario = Gtk.Box(spacing=12, homogeneous=True)
        for entrada in (self.nombre, self.usuario):
            entrada.set_width_chars(8)  # que el texto de ayuda no ensanche el panel
        nombre_usuario.append(fila(_("tu nombre"), self.nombre))
        nombre_usuario.append(fila(_("usuario"), self.usuario))
        caja.append(nombre_usuario)

        self.clave = Gtk.PasswordEntry(show_peek_icon=True)
        self.clave.set_property(
            "placeholder-text", _("al menos {n} caracteres").format(n=MIN_CONTRASENA)
        )
        caja.append(fila(_("contraseña"), self.clave))
        self.clave2 = Gtk.PasswordEntry(show_peek_icon=True)
        self.clave2.connect("activate", self.on_crear)
        caja.append(fila(_("repítela"), self.clave2))

        admin = Gtk.Label(
            label=_("esta cuenta administra el equipo: instala programas y cambia el sistema "
                    "con tu contraseña."),
            xalign=0,
            wrap=True,
            max_width_chars=TEXTO_MAX,
        )
        admin.add_css_class("dato")
        caja.append(admin)

        self.auto = Gtk.Switch(valign=Gtk.Align.CENTER)
        # Con el disco cifrado ya se escribe una contraseña al encender (en el splash): se propone no
        # pedir otra. Es solo la propuesta: el interruptor se puede apagar (docs/cuentas.md).
        cifrado = disco_cifrado()
        self.auto.set_active(cifrado or os.path.exists(f"{CONF}/inicio-automatico-de-serie"))
        auto_texto = Gtk.Label(
            label=_("entrar sin contraseña al encender\n(el disco ya la pide; la pantalla se sigue bloqueando)")
            if cifrado
            else _("entrar sin contraseña al encender\n(la pantalla se sigue bloqueando con ella)"),
            xalign=0,
            hexpand=True,
        )
        auto_fila = Gtk.Box(spacing=12)
        auto_fila.append(auto_texto)
        auto_fila.append(self.auto)
        caja.append(auto_fila)

        self.error = Gtk.Label(xalign=0, wrap=True, max_width_chars=44)
        self.error.add_css_class("error")
        caja.append(self.error)

        self.boton = Gtk.Button(label=_("crear cuenta"))
        self.boton.add_css_class("suggested-action")
        self.boton.connect("clicked", self.on_crear)
        caja.append(self.boton)

        if valores:
            tocado = valores["tocado"]
            self.nombre.set_text(valores["nombre"])  # rellena el usuario si no se había tocado
            self.usuario.set_text(valores["usuario"])
            self.usuario_tocado = tocado
            self.clave.set_text(valores["clave"])
            self.clave2.set_text(valores["clave2"])
            self.auto.set_active(valores["auto"])
        self.set_child(fondo)

    def catalogo(self):
        """Las zonas con los países en el idioma de la ventana (una vez por idioma)."""
        if self.idioma not in self.catalogos:
            self.catalogos[self.idioma] = zonas.catalogo(self.idioma, self._)
        return self.catalogos[self.idioma]

    def construir_zona(self):
        """Botón con la zona elegida que abre un desplegable con buscador: se busca por ciudad,
        país (en el idioma de la ventana) o nombre de la zona, sin tildes."""
        _ = self._
        self.boton_zona = Gtk.MenuButton(hexpand=True)
        self.texto_zona = Gtk.Label(xalign=0, hexpand=True, ellipsize=Pango.EllipsizeMode.END)
        self.boton_zona.set_child(self.texto_zona)

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
        for z in self.catalogo():
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
        self.boton_zona.set_popover(popover)
        self.poner_hora()
        return self.boton_zona

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
        guardar(ZONA, self.zona)
        guardar(ZONA_TOCADA, "1")
        self.poner_hora()
        self.boton_zona.popdown()

    def on_idioma(self, combo, _param):
        codigo = self.idiomas[combo.get_selected()][0]
        if codigo == self.idioma:
            return
        self.idioma = codigo
        guardar(ELEGIDO, codigo)
        valores = {
            "nombre": self.nombre.get_text(), "usuario": self.usuario.get_text(),
            "tocado": self.usuario_tocado, "clave": self.clave.get_text(),
            "clave2": self.clave2.get_text(), "auto": self.auto.get_active(),
        }
        # Al terminar la señal: no se destruye el desplegable mientras la está emitiendo.
        GLib.idle_add(self.repintar, valores)

    def repintar(self, valores):
        self.construir(valores)
        self.combo_idioma.grab_focus()
        return False

    def on_teclado(self, combo, _param):
        codigo = self.teclados[combo.get_selected()][0]
        if codigo == self.teclado:
            return
        os.makedirs(CONF, exist_ok=True)
        with open(f"{CONF}/kb_layout", "w", encoding="utf-8") as f:
            f.write(codigo + "\n")
        # El teclado de un país propone su zona, si no se ha elegido otra a mano ni la actual es ya
        # de ese país.
        sugerida = zonas.sugerida(codigo, self.zona)
        if sugerida and not os.path.exists(ZONA_TOCADA):
            guardar(ZONA, sugerida)
        else:
            guardar(ZONA, self.zona)
        self.get_application().codigo = 3
        self.get_application().quit()

    def on_nombre(self, entrada):
        if not self.usuario_tocado:
            self.usuario.handler_block_by_func(self.on_usuario)
            self.usuario.set_text(usuario_desde(entrada.get_text()))
            self.usuario.handler_unblock_by_func(self.on_usuario)

    def on_usuario(self, _entrada):
        self.usuario_tocado = True

    def fallo(self, texto):
        self.error.remove_css_class("dato")
        self.error.add_css_class("error")
        self.error.set_text(texto)
        self.boton.set_sensitive(True)
        for w in (self.combo_idioma, self.combo, self.boton_zona):
            w.set_sensitive(True)

    def on_crear(self, *_args):
        _ = self._
        if not self.boton.get_sensitive():
            return  # ya se está creando
        usuario = self.usuario.get_text().strip()
        clave = self.clave.get_text()
        if not re.fullmatch(r"[a-z][a-z0-9_-]{0,31}", usuario):
            return self.fallo(_("usuario: minúsculas, números, - o _, empezando por una letra."))
        if len(clave) < MIN_CONTRASENA:
            return self.fallo(
                _("la contraseña tiene que tener al menos {n} caracteres.").format(n=MIN_CONTRASENA)
            )
        if clave != self.clave2.get_text():
            return self.fallo(_("las contraseñas no coinciden."))
        for w in (self.boton, self.combo_idioma, self.combo, self.boton_zona):
            w.set_sensitive(False)
        self.error.remove_css_class("error")
        self.error.add_css_class("dato")
        self.error.set_text(_("creando la cuenta…"))
        orden = [CREAR, "--usuario", usuario, "--teclado", self.teclado, "--idioma", self.idioma,
                 "--zona", self.zona]
        if self.nombre.get_text().strip():
            orden += ["--nombre", self.nombre.get_text().strip()]
        if self.auto.get_active():
            orden.append("--inicio-auto")
        self.clave.set_text("")
        self.clave2.set_text("")
        # En un hilo: aplicar el idioma rehace el menú de arranque (unos segundos) y la ventana no
        # debe congelarse.
        threading.Thread(target=self.crear, args=(orden, clave, usuario), daemon=True).start()

    def crear(self, orden, clave, usuario):
        entorno = dict(os.environ, LANG=self.idioma)
        r = subprocess.run(orden, input=clave + "\n", capture_output=True, text=True, env=entorno)
        GLib.idle_add(self.creada, r, usuario)

    def creada(self, r, usuario):
        _ = self._
        if r.returncode != 0:
            # crear-cuenta da sus errores ya traducidos (corre con LANG del idioma elegido).
            motivo = (r.stderr.strip().splitlines() or [""])[-1].removeprefix("crear-cuenta: ")
            self.fallo(motivo or _("no se pudo crear la cuenta."))
            return False
        self.error.set_text(_("cuenta {usuario} creada. entrando…").format(usuario=usuario))
        GLib.timeout_add(1200, self.get_application().quit)
        return False


class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.commandlab.PrimerArranque")
        self.codigo = 0

    def do_activate(self):
        cargar_tema()
        ventana = Asistente(self)
        ventana.fullscreen()
        ventana.present()


if __name__ == "__main__":
    app = App()
    app.run([])
    sys.exit(app.codigo)
