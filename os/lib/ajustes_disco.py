# Command OS — Ajustes → disco cifrado (lib/ajustes.py; solo sale con el disco cifrado). Cambia
# la contraseña del disco y genera una clave de recuperación nueva. Solo tiene sentido con el disco
# cifrado (`cryptdevice=` en la línea del kernel): Ajustes no enseña la sección sin él.
#
# Lo que toca el disco lo hace lib/gestionar-disco, lanzado con pkexec: polkit pide la contraseña de un
# administrador y, además, se pide la contraseña actual del disco, que va por la entrada estándar (nunca
# como argumento). La clave de recuperación nueva la genera el panel, se enseña una sola vez y hay que
# escribir dos de sus grupos al azar para seguir (como en el instalador): hasta entonces no se cambia
# nada. docs/cifrado.md.
import re
import secrets

from comun import (
    MIN_CONTRASENA, Dialogo, Seccion, administrar, boton, disco_cifrado, problema_clave, texto_clave_corta,
)
from gi.repository import Gtk

HELPER = "/usr/lib/command-os/gestionar-disco"
CIFRAS = 48
GRUPO = 6


def clave_de_recuperacion():
    """48 cifras al azar (como build/x86/lib.sh new_recovery_key)."""
    return "".join(secrets.choice("0123456789") for _ in range(CIFRAS))


def grupos(clave):
    return [clave[i:i + GRUPO] for i in range(0, len(clave), GRUPO)]


class Pagina(Seccion):
    def __init__(self, ventana, traducir):
        super().__init__(ventana, traducir)
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
        self.titulo(_("› disco cifrado"))
        if not disco_cifrado():
            self.nota(_("este equipo no tiene el disco cifrado. se elige al instalar."))
        else:
            self.nota(_("la contraseña del disco se escribe al encender. la clave de recuperación se guarda "
                        "en papel, fuera del equipo, por si se olvida."))
            clave = boton(_("cambiar la contraseña del disco"), halign=Gtk.Align.START)
            clave.connect("clicked", self.al_contrasena)
            self.caja.append(clave)
            recup = boton(_("generar una clave de recuperación nueva"), halign=Gtk.Align.START)
            recup.connect("clicked", self.al_recuperacion)
            self.caja.append(recup)
        self.estado = self.nota(aviso, "error")

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

