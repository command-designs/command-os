#!/usr/bin/env python3
# Command OS — panel del disco cifrado (ventana GTK 4 del escritorio; ajustes → disco cifrado). Cambia
# la contraseña del disco y genera una clave de recuperación nueva. Solo tiene sentido con el disco
# cifrado (`cryptdevice=` en la línea del kernel); si no, lo dice.
#
# Lo que toca el disco lo hace lib/gestionar-disco, lanzado con pkexec: polkit pide la contraseña de un
# administrador y, además, se pide la contraseña actual del disco, que va por la entrada estándar (nunca
# como argumento). La clave de recuperación nueva la genera el panel, se enseña una sola vez y hay que
# escribir dos de sus grupos al azar para seguir (como en el instalador): hasta entonces no se cambia
# nada. docs/cifrado.md.
import re
import secrets
import sys

from comun import (
    MIN_CONTRASENA, Dialogo, PanelBase, administrar, boton, cargar_tema, disco_cifrado, problema_clave, texto_clave_corta,
    traductor,
)
from gi.repository import Gtk

HELPER = "/usr/lib/command-os/gestionar-disco"
CIFRAS = 48
GRUPO = 6
ANCHO = 560


def clave_de_recuperacion():
    """48 cifras al azar (como build/x86/lib.sh new_recovery_key)."""
    return "".join(secrets.choice("0123456789") for _ in range(CIFRAS))


def grupos(clave):
    return [clave[i:i + GRUPO] for i in range(0, len(clave), GRUPO)]


class Panel(PanelBase):
    def __init__(self, app):
        _ = traductor()
        super().__init__(app, _, _("cmd-os · disco cifrado"), ANCHO)
        self.pintar()

    def motivo(self, codigo):
        _ = self._
        return {
            "no_cifrado": _("este equipo no tiene el disco cifrado."),
            "clave_incorrecta": _("la contraseña actual del disco no es correcta (la clave de recuperación no vale aquí)."),
            "clave_corta": texto_clave_corta(_),
            "clave_no_ascii": _("solo letras sin tilde, cifras, espacios y símbolos (sin ñ ni tildes)"),
            "ranuras": _("el disco tiene más claves de las dos habituales: se gestionan a mano con cryptsetup."),
            "autenticacion": _("no se pudo comprobar la contraseña de administrador."),
        }.get(codigo, _("no se pudo completar la operación."))

    def pintar(self, aviso=""):
        _ = self._
        self.limpiar()
        titulo = Gtk.Label(label=_("› disco cifrado"), xalign=0)
        titulo.add_css_class("titulo")
        self.caja.append(titulo)
        if not disco_cifrado():
            texto = Gtk.Label(
                label=_("este equipo no tiene el disco cifrado. se elige al instalar."),
                xalign=0, wrap=True, max_width_chars=54,
            )
            texto.add_css_class("tenue")
            self.caja.append(texto)
        else:
            intro = Gtk.Label(
                label=_("la contraseña del disco se escribe al encender. la clave de recuperación se guarda "
                        "en papel, fuera del equipo, por si se olvida."),
                xalign=0, wrap=True, max_width_chars=54,
            )
            intro.add_css_class("tenue")
            self.caja.append(intro)
            clave = boton(_("cambiar la contraseña del disco"), halign=Gtk.Align.START)
            clave.connect("clicked", self.al_contrasena)
            self.caja.append(clave)
            recup = boton(_("generar una clave de recuperación nueva"), halign=Gtk.Align.START)
            recup.connect("clicked", self.al_recuperacion)
            self.caja.append(recup)
        self.estado = Gtk.Label(label=aviso, xalign=0, wrap=True, max_width_chars=54)
        self.estado.add_css_class("error")
        self.caja.append(self.estado)
        cerrar = boton(_("cerrar"), halign=Gtk.Align.END)
        cerrar.add_css_class("flat")
        cerrar.connect("clicked", lambda _b: self.ventana.close())
        self.caja.append(cerrar)

    def hecho(self, texto):
        """Tras un cambio bien hecho: repinta con el aviso en el color de los datos."""
        self.pintar(texto)
        self.estado.remove_css_class("error")
        self.estado.add_css_class("dato")

    # ---- Contraseña del disco -------------------------------------------------------------------

    def al_contrasena(self, _boton):
        _ = self._
        campos = [
            ("actual", _("contraseña actual del disco"), "clave", None),
            ("nueva", _("contraseña nueva"), "clave", None),
            ("repetir", _("repítela"), "clave", None),
        ]
        intro = _("se pide al encender, antes de que arranque el sistema: al menos 8 caracteres, sin ñ ni tildes.")
        Dialogo(self.ventana, _("contraseña del disco"), intro, campos, _("cambiar"), self.hacer_contrasena, _).present()

    def hacer_contrasena(self, dialogo, v):
        _ = self._
        if len(v["nueva"]) < MIN_CONTRASENA:
            return self.motivo("clave_corta")
        if not re.fullmatch(r"[ -~]+", v["nueva"]):
            return self.motivo("clave_no_ascii")
        if problema := problema_clave(v["nueva"], v["repetir"], _):
            return problema

        def hecho(codigo):
            if codigo:
                dialogo.mostrar_error("" if codigo == "cancelado" else self.motivo(codigo))
            else:
                dialogo.close()
                self.hecho(_("contraseña del disco cambiada. se pide la nueva al encender."))
        self.en_hilo(lambda: administrar(HELPER, ["contrasena"], v["actual"] + "\n" + v["nueva"] + "\n"), hecho)
        return None

    # ---- Clave de recuperación -------------------------------------------------------------------

    def al_recuperacion(self, _boton):
        _ = self._
        nueva = clave_de_recuperacion()
        partes = grupos(nueva)
        # Dos grupos al azar, distintos: comprueban que se ha apuntado antes de cambiar nada.
        a, b = sorted(secrets.SystemRandom().sample(range(len(partes)), 2))
        mostrada = "\n".join(" ".join(partes[i:i + 4]) for i in (0, 4))
        campos = [
            ("g1", _("grupo {n}").format(n=a + 1), "texto", None),
            ("g2", _("grupo {n}").format(n=b + 1), "texto", None),
            ("actual", _("contraseña actual del disco"), "clave", None),
        ]
        intro = _("apunta esta clave en papel y guárdala fuera del equipo: es la única forma de entrar si se "
                  "olvida la contraseña. se enseña una sola vez. la clave de recuperación anterior dejará de valer.")

        def aceptar(dialogo, v):
            if v["g1"].strip() != partes[a] or v["g2"].strip() != partes[b]:
                return _("los grupos no coinciden con la clave: vuelve a mirarla.")
            if not v["actual"]:
                return self.motivo("clave_incorrecta")

            def hecho(codigo):
                if codigo:
                    dialogo.mostrar_error("" if codigo == "cancelado" else self.motivo(codigo))
                else:
                    dialogo.close()
                    self.hecho(_("clave de recuperación cambiada: la anterior ya no vale."))
            self.en_hilo(lambda: administrar(HELPER, ["recuperacion"], v["actual"] + "\n" + nueva + "\n"), hecho)
            return None
        Dialogo(self.ventana, _("clave de recuperación"), intro, campos, _("cambiar"), aceptar, _,
                destacado=mostrada).present()


class App(Gtk.Application):
    def __init__(self):
        super().__init__(application_id="dev.commandlab.DiscoCifrado")
        self.panel = None

    def do_activate(self):
        cargar_tema()
        if self.panel is None:
            self.panel = Panel(self)
        self.panel.ventana.present()


if __name__ == "__main__":
    sys.exit(App().run([]))
