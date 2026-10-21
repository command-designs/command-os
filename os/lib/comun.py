# Command OS — piezas comunes de las ventanas GTK 4: la entrada al equipo (lib/greeter.py y
# lib/primer-arranque.py), Ajustes y sus secciones (lib/ajustes.py) y los paneles sueltos: lectura del
# estado, traducciones, filas del formulario, tema y logo.
import os
import re
import subprocess
import threading
import unicodedata

import gi

gi.require_version("Gdk", "4.0")
gi.require_version("Gtk", "4.0")
from gi.repository import Gdk, GdkPixbuf, GLib, Gtk  # noqa: E402
from traducir import DOMINIO, LOCALES, traductor  # noqa: E402,F401

CONF = "/etc/command-os"
CSS = "/usr/share/command-os/greeter/command.css"
LOGO = "/usr/share/command-os/logo/command-wordmark-white.png"

# Reglas de las cuentas. La copia en shell es lib/reglas.sh: misma longitud mínima y mismo patrón de
# usuario (si se cambia una, se cambia la otra; tests/cuentas.sh comprueba que coinciden).
MIN_CONTRASENA = 8
USUARIO_ER = r"[a-z][a-z0-9_-]{0,31}"


def leer(ruta, defecto=""):
    try:
        with open(ruta, encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return defecto


def disco_cifrado(cmdline="/proc/cmdline"):
    """True si el sistema arrancó desde un disco cifrado (`cryptdevice=` en la línea del kernel, que
    ponen el instalador de PC y command-os-rollback; docs/cifrado.md)."""
    return any(p.startswith("cryptdevice=") for p in leer(cmdline).split())


def usuario_desde(nombre):
    """«Ana López» -> «ana»: primera palabra, sin tildes, en minúsculas."""
    plano = unicodedata.normalize("NFKD", nombre).encode("ascii", "ignore").decode()
    palabra = (plano.lower().split() or [""])[0]
    return re.sub(r"[^a-z0-9_-]", "", palabra)[:32]


def usuario_valido(usuario):
    return re.fullmatch(USUARIO_ER, usuario) is not None


def texto_usuario_invalido(_):
    return _("usuario: minúsculas, números, - o _, empezando por una letra.")


def texto_clave_corta(_):
    return _("la contraseña tiene que tener al menos {n} caracteres.").format(n=MIN_CONTRASENA)


def problema_clave(nueva, repetir, _):
    """Por qué no vale una contraseña nueva y su repetición (el texto), o None si vale."""
    if len(nueva) < MIN_CONTRASENA:
        return texto_clave_corta(_)
    if nueva != repetir:
        return _("las contraseñas no coinciden.")
    return None


def boton(texto, **kw):
    """Botón con el texto en mayúsculas: los botones van en mono mayúsculas (BRAND § 5) y el CSS de
    GTK no tiene text-transform. El texto traducible sigue en minúsculas (`_("cerrar")`)."""
    return Gtk.Button(label=texto.upper(), **kw)


def fila(etiqueta, widget):
    """Etiqueta mono en Smoke y en mayúsculas (como las de lenguaje.html) encima del campo."""
    caja = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=4)
    texto = Gtk.Label(label=etiqueta.upper(), xalign=0)
    texto.add_css_class("etiqueta")
    caja.append(texto)
    caja.append(widget)
    return caja


def logo(alto):
    """El wordmark a una altura fija (a tamaño natural ensancharía todo el panel), o None."""
    if not os.path.exists(LOGO):
        return None
    imagen = GdkPixbuf.Pixbuf.new_from_file_at_scale(LOGO, 400, alto, True)
    pic = Gtk.Picture.new_for_paintable(Gdk.Texture.new_for_pixbuf(imagen))
    pic.set_content_fit(Gtk.ContentFit.SCALE_DOWN)
    # Sin esto el logo se encoge a 0 px cuando el panel no cabe y el panel se comprime en vez de
    # desplazarse (1024x600).
    pic.set_can_shrink(False)
    pic.set_halign(Gtk.Align.CENTER)
    return pic


def panel(ancho):
    """Panel central con chaflán sobre el fondo, enmarcado por las escuadras de la zona principal
    (marca v2, docs/DISENO.md); devuelve (fondo, panel).

    Va dentro de un ScrolledWindow: en una pantalla baja (1024x600) el formulario no cabe y, sin
    desplazamiento, el botón quedaría fuera de la pantalla. Si cabe, no se nota: sigue centrado."""
    caja = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
    caja.add_css_class("panel")
    caja.set_size_request(ancho, -1)
    marco = Gtk.Box()
    marco.add_css_class("escuadras")
    marco.set_halign(Gtk.Align.CENTER)
    marco.set_valign(Gtk.Align.CENTER)
    marco.set_hexpand(True)
    marco.append(caja)
    desliza = Gtk.ScrolledWindow(
        hscrollbar_policy=Gtk.PolicyType.NEVER,
        vscrollbar_policy=Gtk.PolicyType.AUTOMATIC,
        hexpand=True,
        vexpand=True,
    )
    desliza.set_child(marco)
    fondo = Gtk.Box(hexpand=True)
    fondo.add_css_class("fondo")
    fondo.append(desliza)
    return fondo, caja


def ventana(app, titulo, ancho, alto_max=640):
    """Ventana normal (no a pantalla completa) con el tema de Command OS: devuelve (ventana, caja).
    Paneles del escritorio (actualizaciones, cuentas, disco). Si el contenido es más alto que la
    pantalla, se desplaza (como `panel`)."""
    v = Gtk.ApplicationWindow(application=app, title=titulo)
    v.set_default_size(ancho, -1)
    v.set_resizable(False)
    caja = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
    caja.add_css_class("panel-ventana")
    caja.set_size_request(ancho, -1)
    desliza = Gtk.ScrolledWindow(
        hscrollbar_policy=Gtk.PolicyType.NEVER,
        vscrollbar_policy=Gtk.PolicyType.AUTOMATIC,
        propagate_natural_height=True,
        max_content_height=alto_max,
    )
    desliza.set_child(caja)
    v.set_child(desliza)
    return v, caja


def escape_cierra(ventana):
    """Escape cierra la ventana (paneles y diálogos)."""
    def tecla(_controlador, valor, _codigo, _estado):
        if valor == 0xFF1B:  # Escape
            ventana.close()
            return True
        return False
    teclas = Gtk.EventControllerKey()
    teclas.connect("key-pressed", tecla)
    ventana.add_controller(teclas)


def en_hilo(trabajo, hecho):
    """trabajo() en un hilo (lo que tarda: nmcli, pkexec…); hecho(resultado) en el hilo de la ventana."""
    def correr():
        resultado = trabajo()
        GLib.idle_add(lambda: (hecho(resultado), False)[1])
    threading.Thread(target=correr, daemon=True).start()


def interruptor(texto, activo, al_cambiar, detalle=""):
    """Fila con el texto (y un detalle tenue debajo) a la izquierda y un interruptor a la derecha.
    al_cambiar(interruptor, activo) es la señal state-set de GTK: devuelve True para dejar el
    interruptor como estaba hasta saber el resultado. Devuelve (fila, interruptor)."""
    fila = Gtk.Box(spacing=12)
    textos = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, hexpand=True, valign=Gtk.Align.CENTER)
    textos.append(Gtk.Label(label=texto, xalign=0, wrap=True, max_width_chars=44))
    if detalle:
        d = Gtk.Label(label=detalle, xalign=0, wrap=True, max_width_chars=44)
        d.add_css_class("tenue")
        textos.append(d)
    fila.append(textos)
    boton = Gtk.Switch(active=activo, valign=Gtk.Align.CENTER)
    boton.connect("state-set", al_cambiar)
    fila.append(boton)
    return fila, boton


class Deslizador(Gtk.Box):
    """Un nivel de 0 a 100 (volumen, brillo) con su icono delante y la cifra detrás. Al arrastrar, aplica
    el último valor cada 80 ms como mucho, no en cada píxel; poner() lo cambia desde fuera sin aplicarlo.
    al_icono: clic en el icono (silenciar), o None."""

    def __init__(self, icono, valor, aplicar, al_icono=None, minimo=0):
        super().__init__(spacing=10)
        self.add_css_class("deslizador")
        self.aplicar = aplicar
        self.pendiente = None
        self.desde_fuera = False
        if al_icono:
            self.icono = Gtk.Button(icon_name=icono, valign=Gtk.Align.CENTER)
            self.icono.add_css_class("flat")
            self.icono.connect("clicked", lambda _b: al_icono())
        else:
            self.icono = Gtk.Image.new_from_icon_name(icono)
        self.append(self.icono)
        self.escala = Gtk.Scale.new_with_range(Gtk.Orientation.HORIZONTAL, minimo, 100, 1)
        self.escala.set_hexpand(True)
        self.escala.set_draw_value(False)
        self.escala.set_value(valor)
        self.escala.connect("value-changed", self.al_mover)
        self.append(self.escala)
        self.cifra = Gtk.Label(label=f"{int(valor)} %", xalign=1, width_chars=5)
        self.cifra.add_css_class("dato")
        self.append(self.cifra)

    def poner(self, valor, icono=None):
        self.desde_fuera = True
        self.escala.set_value(valor)
        self.desde_fuera = False
        self.cifra.set_text(f"{int(valor)} %")
        if icono and isinstance(self.icono, Gtk.Button):
            self.icono.set_icon_name(icono)
        elif icono:
            self.icono.set_from_icon_name(icono)

    def al_mover(self, escala):
        valor = int(escala.get_value())
        self.cifra.set_text(f"{valor} %")
        if self.desde_fuera:
            return
        if self.pendiente is None:
            GLib.timeout_add(80, self.aplicar_pendiente)
        self.pendiente = valor

    def aplicar_pendiente(self):
        valor, self.pendiente = self.pendiente, None
        if valor is not None:
            self.aplicar(valor)
        return False


def lanzar(orden):
    """Abre un programa aparte (las herramientas de «avanzado», la terminal): sigue solo al cerrar la ventana."""
    try:
        subprocess.Popen(orden, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    except OSError:
        pass


class Contenido:
    """Lo común de un panel suelto y de una sección de Ajustes: limpiar la caja antes de repintar y el
    trabajo en un hilo. Los hijos ponen self._ (el traductor) y self.caja."""

    caja: Gtk.Box

    def limpiar(self):
        while (hijo := self.caja.get_first_child()) is not None:
            self.caja.remove(hijo)

    def en_hilo(self, trabajo, hecho):
        en_hilo(trabajo, hecho)

    def titulo(self, texto):
        """El titular de la ventana o la sección (`› cuentas`), en Oxanium."""
        t = Gtk.Label(label=texto, xalign=0)
        t.add_css_class("titulo")
        self.caja.append(t)
        return t

    def nota(self, texto, clase="tenue"):
        """Un párrafo que se parte en líneas (tenue: explicación; dato: un valor; error)."""
        t = Gtk.Label(label=texto, xalign=0, wrap=True, max_width_chars=60)
        t.add_css_class(clase)
        self.caja.append(t)
        return t

    def etiqueta(self, texto):
        """Rótulo de un grupo (mono, Smoke y en mayúsculas, como `fila`)."""
        t = Gtk.Label(label=texto.upper(), xalign=0)
        t.add_css_class("etiqueta")
        self.caja.append(t)
        return t


class PanelBase(Contenido):
    """Un panel suelto del escritorio (abrir descarga): la ventana con el tema y Escape para cerrar.
    traducir: el traductor del panel (el título lo traduce cada panel, para que xgettext lo vea)."""

    def __init__(self, app, traducir, titulo, ancho, alto_max=640):
        self._ = traducir
        self.ventana, self.caja = ventana(app, titulo, ancho, alto_max)
        escape_cierra(self.ventana)


class Seccion(Contenido):
    """Una sección de Ajustes (lib/ajustes.py): self.caja es lo que se pinta a la derecha y self.ventana la
    ventana de Ajustes (el padre de los diálogos). Ajustes la construye la primera vez que se abre y llama
    a mostrar() y ocultar() al cambiar de sección: lo que se pone al día solo (cada) corre solo mientras
    la sección está a la vista, nunca en segundo plano (AGENTS.md § «Ligereza»)."""

    def __init__(self, ventana, traducir):
        self._ = traducir
        self.ventana = ventana
        self.caja = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=14)
        self.caja.add_css_class("seccion")
        self._relojes = []
        self._activos = []
        self._vista = False

    def cada(self, segundos, funcion):
        """funcion() cada tantos segundos mientras la sección está a la vista."""
        self._relojes.append((segundos, funcion))

    def mostrar(self):
        if self._vista:  # la primera vez acaba de construirse: ya está al día
            self.al_mostrar()
        self._vista = True
        self._activos = [GLib.timeout_add_seconds(s, lambda f=f: (f(), True)[1]) for s, f in self._relojes]

    def ocultar(self):
        for fuente in self._activos:
            GLib.source_remove(fuente)
        self._activos = []

    def al_mostrar(self):
        """Al volver a la sección: los hijos repintan lo que pueda haber cambiado fuera."""

    def avanzado(self, herramientas):
        """El bloque «avanzado» del final: [(texto, orden)], las herramientas completas para lo que la
        sección no cubre. Se abren aparte y Ajustes sigue abierto."""
        if not herramientas:
            return
        self.etiqueta(self._("avanzado"))
        caja = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=2)
        caja.add_css_class("avanzado")
        for texto, orden in herramientas:
            b = Gtk.Button(halign=Gtk.Align.START)
            b.add_css_class("flat")
            b.set_child(Gtk.Label(label=f"{texto}  ›", xalign=0))
            b.connect("clicked", lambda _b, o=orden: lanzar(o))
            caja.append(b)
        self.caja.append(caja)


def administrar(ayudante, args, entrada=""):
    """Ejecuta un ayudante de root (lib/gestionar-cuentas, lib/gestionar-disco) con pkexec: polkit pide la
    contraseña de un administrador y el panel no la ve. Devuelve None si fue bien o un código de error:
    el que da el ayudante («error: CÓDIGO»), `cancelado` (se cerró el diálogo de polkit) o `autenticacion`."""
    try:
        r = subprocess.run(["pkexec", ayudante, *args], input=entrada, capture_output=True, text=True, timeout=300)
    except (OSError, subprocess.SubprocessError):
        return "fallo"
    if r.returncode == 0:
        return None
    if r.returncode == 126:
        return "cancelado"
    if r.returncode == 127:
        return "autenticacion"
    m = re.search(r"error: (\w+)", r.stderr)
    return m.group(1) if m else "fallo"


class Dialogo(Gtk.Window):
    """Formulario modal. campos: [(clave, etiqueta, tipo, extra)]; tipos: texto, clave, interruptor, lista
    (extra = los nombres). al_aceptar(dialogo, valores) arranca el trabajo; el diálogo ya ha pasado a
    «ocupado» y lo cierra o le da un error cuando termina (cerrar_con / mostrar_error)."""

    def __init__(self, padre, titulo, intro, campos, texto_boton, al_aceptar, traducir, destacado=""):
        super().__init__(title=titulo, transient_for=padre, modal=True, resizable=False)
        self._ = _ = traducir
        self.al_aceptar = al_aceptar
        self.widgets = {}
        caja = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=12)
        caja.add_css_class("panel-ventana")
        caja.set_size_request(440, -1)
        cabecera = Gtk.Label(label=f"› {titulo}", xalign=0)
        cabecera.add_css_class("titulo")
        caja.append(cabecera)
        if intro:
            texto = Gtk.Label(label=intro, xalign=0, wrap=True, max_width_chars=48)
            texto.add_css_class("tenue")
            caja.append(texto)
        if destacado:
            # Un dato que hay que leer con calma (la clave de recuperación): monoespaciado.
            grande = Gtk.Label(label=destacado, xalign=0)
            grande.add_css_class("clave")
            caja.append(grande)
        for clave, etiqueta, tipo, extra in campos:
            if tipo == "texto":
                w = Gtk.Entry()
                w.connect("activate", self.aceptar)
            elif tipo == "clave":
                w = Gtk.PasswordEntry(show_peek_icon=True)
                w.connect("activate", self.aceptar)
            elif tipo == "interruptor":
                w = Gtk.Switch(halign=Gtk.Align.START)
            else:
                w = Gtk.DropDown.new_from_strings(extra)
            self.widgets[clave] = (tipo, w)
            caja.append(fila(etiqueta, w))
        self.error = Gtk.Label(xalign=0, wrap=True, max_width_chars=48)
        self.error.add_css_class("error")
        caja.append(self.error)
        botones = Gtk.Box(spacing=10, halign=Gtk.Align.END)
        cancelar = boton(_("cancelar"))
        cancelar.add_css_class("flat")
        cancelar.connect("clicked", lambda _b: self.close())
        botones.append(cancelar)
        self.boton = boton(texto_boton)
        self.boton.add_css_class("suggested-action")
        self.boton.connect("clicked", self.aceptar)
        botones.append(self.boton)
        caja.append(botones)
        self.set_child(caja)
        escape_cierra(self)

    def valores(self):
        v = {}
        for clave, (tipo, w) in self.widgets.items():
            if tipo in ("texto", "clave"):
                v[clave] = w.get_text()
            elif tipo == "interruptor":
                v[clave] = w.get_active()
            else:
                v[clave] = w.get_selected()
        return v

    def aceptar(self, *_args):
        if not self.boton.get_sensitive():
            return
        motivo = self.al_aceptar(self, self.valores())
        if motivo:
            self.mostrar_error(motivo)
        else:
            self.error.set_text("")
            self.boton.set_sensitive(False)

    def mostrar_error(self, texto):
        self.error.set_text(texto)
        self.boton.set_sensitive(True)


def cargar_tema():
    css = Gtk.CssProvider()
    if os.path.exists(CSS):
        css.load_from_path(CSS)
    Gtk.StyleContext.add_provider_for_display(
        Gdk.Display.get_default(), css, Gtk.STYLE_PROVIDER_PRIORITY_USER
    )
