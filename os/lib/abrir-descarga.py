#!/usr/bin/env python3
# Command OS — abre los archivos descargados que no son de ninguna aplicación (command-os-abrir-descarga;
# lo eligen las asociaciones de tipos de serie, /usr/share/applications/mimeapps.list). Ventana GTK 4:
#   - AppImage: avisa de que es un programa descargado y, si se acepta, lo marca como ejecutable y lo
#     abre (antes comprueba que sea para el procesador de este equipo);
#   - .deb y .rpm: son de otras distribuciones; explica por qué y busca la aplicación en la tienda;
#   - .flatpakrepo: añade ese repositorio de Flatpak a la tienda si se confirma.
# docs/notas/escritorio.md § «Instalar aplicaciones».
import os
import stat
import subprocess
import sys

from comun import cargar_tema, traductor, ventana
from descargas import busqueda, otro_procesador, repositorio, tipo

from gi.repository import Gio, GLib, Gtk  # noqa: E402

ANCHO = 500


class Panel:
    def __init__(self, app, ruta):
        self._ = _ = traductor()
        self.ruta = ruta
        self.ventana, self.caja = ventana(app, _("cmd-os · abrir descarga"), ANCHO)
        teclas = Gtk.EventControllerKey()
        teclas.connect("key-pressed", self.tecla)
        self.ventana.add_controller(teclas)
        self.pintar()

    def tecla(self, _controlador, valor, _codigo, _estado):
        if valor == 0xFF1B:  # Escape
            self.ventana.close()
            return True
        return False

    def limpiar(self):
        while (hijo := self.caja.get_first_child()) is not None:
            self.caja.remove(hijo)

    def texto(self, contenido, clase="tenue"):
        etiqueta = Gtk.Label(label=contenido, xalign=0, wrap=True, max_width_chars=52)
        etiqueta.add_css_class(clase)
        self.caja.append(etiqueta)
        return etiqueta

    def botones(self, principal=None, al_pulsar=None, cerrar=None):
        _ = self._
        fila = Gtk.Box(spacing=10, halign=Gtk.Align.END)
        salir = Gtk.Button(label=cerrar or (_("cancelar") if principal else _("cerrar")))
        salir.add_css_class("flat")
        salir.connect("clicked", lambda _b: self.ventana.close())
        fila.append(salir)
        if principal:
            boton = Gtk.Button(label=principal)
            boton.add_css_class("suggested-action")
            boton.connect("clicked", al_pulsar)
            fila.append(boton)
            self.ventana.set_default_widget(boton)
        self.caja.append(fila)

    def cabecera(self, contenido):
        titulo = Gtk.Label(label=contenido, xalign=0)
        titulo.add_css_class("titulo")
        self.caja.append(titulo)

    def pintar(self):
        _ = self._
        archivo = os.path.basename(self.ruta)
        t = tipo(self.ruta)
        self.error = None  # la etiqueta de errores, solo en las ventanas con botón principal
        if not os.path.isfile(self.ruta):
            self.cabecera(_("› abrir descarga"))
            self.texto(_("el archivo «{archivo}» ya no existe.").format(archivo=archivo), "error")
            self.botones()
        elif t == "appimage":
            self.cabecera(_("› abrir un programa descargado"))
            self.texto(_("«{archivo}» es un programa descargado de internet (AppImage). ábrelo solo si viene de un "
                         "sitio en el que confíes: podrá usar tus archivos como cualquier otro programa.")
                       .format(archivo=archivo))
            self.error = self.texto("", "error")
            self.botones(_("abrir"), self.abrir_appimage)
        elif t in ("debian", "rpm"):
            self.cabecera(_("› paquete de otro sistema"))
            if t == "debian":
                explica = _("«{archivo}» es un paquete para debian y ubuntu: en command os las aplicaciones no se "
                            "instalan así. búscala en la tienda de aplicaciones, que tiene la versión que funciona "
                            "en este equipo y la mantiene al día.")
            else:
                explica = _("«{archivo}» es un paquete para fedora y opensuse: en command os las aplicaciones no se "
                            "instalan así. búscala en la tienda de aplicaciones, que tiene la versión que funciona "
                            "en este equipo y la mantiene al día.")
            self.texto(explica.format(archivo=archivo))
            self.botones(_("buscar en la tienda"), self.buscar, _("cerrar"))
        elif t == "repositorio" and (repo := repositorio(self.ruta)):
            self.repo = repo
            self.cabecera(_("› añadir un repositorio de aplicaciones"))
            self.texto(_("«{titulo}» ({url}) es un repositorio de aplicaciones Flatpak. añádelo solo si confías en "
                         "quien lo publica: sus aplicaciones saldrán en la tienda.").format(titulo=repo[1], url=repo[2]))
            self.error = self.texto("", "error")
            self.botones(_("añadir"), self.anadir_repositorio)
        else:
            self.cabecera(_("› abrir descarga"))
            self.texto(_("command os no sabe abrir «{archivo}».").format(archivo=archivo), "error")
            self.botones()

    def abrir_appimage(self, boton):
        _ = self._
        este = os.uname().machine
        if suyo := otro_procesador(self.ruta, este):
            self.error.set_text(_("este programa es para otro tipo de procesador ({suyo}) y no funciona en este "
                                  "equipo ({este}).").format(suyo=suyo, este=este))
            return
        ruta = os.path.abspath(self.ruta)
        try:
            modo = os.stat(ruta).st_mode
            if not modo & stat.S_IXUSR:
                os.chmod(ruta, modo | stat.S_IXUSR)
        except OSError:
            self.error.set_text(_("no se pudo abrir el programa: puede que el archivo no sea tuyo o esté dañado."))
            return
        try:
            proceso = subprocess.Popen([ruta], cwd=os.path.dirname(ruta), stdin=subprocess.DEVNULL,
                                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        except PermissionError:
            # Ya es ejecutable: es el disco el que no deja ejecutar programas (noexec: USB, /tmp).
            self.error.set_text(_("este disco no deja abrir programas: copia el archivo a tu carpeta personal y "
                                  "ábrelo desde allí."))
            return
        except OSError:
            self.error.set_text(_("no se pudo abrir el programa: puede que el archivo no sea tuyo o esté dañado."))
            return
        boton.set_sensitive(False)
        self.error.set_text("")
        inicio = GLib.get_monotonic_time()

        # Si se cierra con error nada más abrirse, se dice aquí (si no, no se vería nada); si sigue en
        # marcha a los 3 s, la ventana se cierra y el programa sigue solo.
        def vigilar():
            codigo = proceso.poll()
            if codigo is not None and codigo != 0:
                self.error.set_text(_("el programa se cerró nada más abrirse: puede que esté dañado o que necesite "
                                      "algo que este equipo no tiene."))
                boton.set_sensitive(True)
                return False
            if codigo == 0 or GLib.get_monotonic_time() - inicio > 3_000_000:
                self.ventana.close()
                return False
            return True
        GLib.timeout_add(200, vigilar)

    def buscar(self, _boton):
        try:
            subprocess.Popen(["command-os-tienda", "buscar", busqueda(self.ruta)], start_new_session=True,
                             stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except OSError:
            pass
        self.ventana.close()

    def anadir_repositorio(self, boton):
        _ = self._
        nombre = self.repo[0]
        # Con --if-not-exists, flatpak no hace nada (y sale bien) si ya hay un remoto con ese nombre, aunque
        # sea de otra dirección: se avisa antes.
        try:
            remotos = subprocess.run(["flatpak", "remotes", "--system", "--columns=name"], capture_output=True,
                                     text=True, timeout=30).stdout.split()
        except (OSError, subprocess.SubprocessError):
            remotos = []
        if nombre in remotos:
            self.error.set_text(_("ya hay un repositorio llamado «{nombre}» en la tienda.").format(nombre=nombre))
            return
        boton.set_sensitive(False)
        # Flatpak pide permiso a polkit (las cuentas administradoras de la sesión activa, sin contraseña).
        try:
            proceso = Gio.Subprocess.new(
                ["flatpak", "remote-add", "--system", "--if-not-exists", "--from", nombre, os.path.abspath(self.ruta)],
                Gio.SubprocessFlags.STDOUT_SILENCE | Gio.SubprocessFlags.STDERR_SILENCE)
        except GLib.Error:
            self.error.set_text(_("no se pudo añadir el repositorio."))
            boton.set_sensitive(True)
            return

        def hecho(p, resultado):
            try:
                ok = p.wait_check_finish(resultado)
            except GLib.Error:
                ok = False
            self.limpiar()
            if ok:
                self.cabecera(_("› añadir un repositorio de aplicaciones"))
                self.texto(_("repositorio añadido: sus aplicaciones ya salen en la tienda."), "dato")
                self.botones()
            else:
                self.pintar()  # si el archivo ya no está, lo dice en vez del error
                if self.error is not None:
                    self.error.set_text(_("no se pudo añadir el repositorio."))
        proceso.wait_check_async(None, hecho)


class App(Gtk.Application):
    def __init__(self, ruta):
        # Sin ventana única: dos descargas abiertas a la vez son dos ventanas.
        super().__init__(application_id="dev.commandlab.AbrirDescarga", flags=Gio.ApplicationFlags.NON_UNIQUE)
        self.ruta = ruta
        self.panel = None

    def do_activate(self):
        cargar_tema()
        if self.panel is None:
            self.panel = Panel(self, self.ruta)
        self.panel.ventana.present()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("uso: command-os-abrir-descarga ARCHIVO", file=sys.stderr)
        sys.exit(2)
    sys.exit(App(sys.argv[1]).run([]))
