# Command OS — Ajustes → idioma y hora (lib/ajustes.py). El idioma de esta cuenta (propio o el del equipo),
# el idioma del equipo y la zona horaria del equipo.
#
# El idioma propio es ~/.config/locale.conf (lo lee lib/entorno-grafico al abrir la sesión); si su locale
# no está generado, lo genera lib/gestionar-cuentas. El idioma y la zona del equipo los cambia también
# gestionar-cuentas: pkexec pide la contraseña de un administrador cada vez. docs/cuentas.md e idioma.md.
import os
import pwd
import subprocess

import zonas
from comun import Seccion, administrar, fila, leer
from gi.repository import Gtk
from selector_zona import SelectorZona

HELPER = "/usr/lib/command-os/gestionar-cuentas"
LOCALE_CONF = "/etc/locale.conf"


def idiomas():
    """[(locale, nombre en su idioma)] de command-os-idioma."""
    try:
        r = subprocess.run(["command-os-idioma", "lista"], capture_output=True, text=True, check=True)
        return [tuple(linea.split(" ", 1)) for linea in r.stdout.splitlines() if " " in linea]
    except (OSError, subprocess.CalledProcessError):
        return []


def locale_generado(loc):
    try:
        r = subprocess.run(["locale", "-a"], capture_output=True, text=True, check=True)
    except (OSError, subprocess.CalledProcessError):
        return False
    return loc.split(".")[0].lower() + ".utf8" in {linea.strip().lower() for linea in r.stdout.splitlines()}


def archivo_idioma():
    return os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "locale.conf")


def lang_de(ruta):
    """El LANG de un locale.conf, o '' si no lo tiene."""
    for linea in leer(ruta).splitlines():
        if linea.startswith("LANG="):
            return linea[5:].strip("\"'")
    return ""


def idioma_propio():
    """El LANG del idioma propio de la cuenta (~/.config/locale.conf) o '' si usa el del equipo."""
    return lang_de(archivo_idioma())


def poner_idioma_propio(loc, usuario):
    """El idioma propio de la cuenta ('' = el del equipo). None si fue bien o un código de error."""
    if not loc:
        try:
            os.remove(archivo_idioma())
        except FileNotFoundError:
            pass
        except OSError:
            return "fallo"
        return None
    if locale_generado(loc):
        try:
            os.makedirs(os.path.dirname(archivo_idioma()), exist_ok=True)
            with open(archivo_idioma(), "w", encoding="utf-8") as f:
                f.write(f"LANG={loc}\n")
        except OSError:
            return "fallo"
        return None
    return administrar(HELPER, ["idioma", usuario, loc])  # hay que generar el locale (root)


class Pagina(Seccion):
    def __init__(self, ventana, traducir):
        super().__init__(ventana, traducir)
        self.yo = pwd.getpwuid(os.getuid())
        self.idiomas = idiomas()
        self.pintar()
        # La hora del botón de la zona, al día.
        self.cada(20, lambda: self.selector.poner_hora())

    def motivo(self, codigo):
        _ = self._
        return {
            "idioma_no_disponible": _("ese idioma no está disponible."),
            "zona_no_disponible": _("esa zona horaria no está disponible."),
            "autenticacion": _("no se pudo comprobar la contraseña de administrador."),
        }.get(codigo, _("no se pudo completar la operación."))

    def pintar(self):
        _ = self._
        self.titulo(_("› idioma y hora"))

        nombres = [_("el del equipo")] + [n for _loc, n in self.idiomas]
        self.codigos = [""] + [loc for loc, _n in self.idiomas]
        self.combo_propio = Gtk.DropDown.new_from_strings(nombres)
        actual = idioma_propio()
        self.combo_propio.set_selected(self.codigos.index(actual) if actual in self.codigos else 0)
        self.propio_pintado = self.combo_propio.get_selected()
        self.combo_propio.connect("notify::selected", self.al_idioma_propio)
        self.caja.append(fila(_("idioma de mi cuenta"), self.combo_propio))
        self.nota(_("ventanas, barra y menús de tu cuenta; se aplica al volver a entrar."))

        locales = [loc for loc, _n in self.idiomas]
        self.combo_equipo = Gtk.DropDown.new_from_strings([n for _loc, n in self.idiomas] or ["—"])
        del_equipo = lang_de(LOCALE_CONF)
        if del_equipo in locales:
            self.combo_equipo.set_selected(locales.index(del_equipo))
        self.equipo_pintado = self.combo_equipo.get_selected()
        self.combo_equipo.connect("notify::selected", self.al_idioma_equipo)
        self.caja.append(fila(_("idioma del equipo"), self.combo_equipo))
        self.nota(_("el de la pantalla de inicio, el arranque y las cuentas sin idioma propio. "
                    "pide la contraseña de un administrador y se aplica del todo al reiniciar."))

        idioma = os.environ.get("LANG", "es_ES.UTF-8")
        validas = {z for z, _c in zonas.zonas()}
        zona = zonas.actual()
        if zona not in validas:
            zona = "UTC"
        pared = zona if zonas.reloj_local() and not zonas.sincronizada() else None
        self.zona_pintada = zona
        self.selector = SelectorZona(zonas.catalogo(idioma, _), _, zona, self.al_zona, pared)
        self.caja.append(fila(_("zona horaria (de todo el equipo)"), self.selector))
        self.nota(_("la hora se pone sola por la red. cambiar la zona pide la contraseña de un administrador."))

        self.estado = self.nota("", "error")

    def avisar(self, texto, error=True):
        self.estado.remove_css_class("dato" if error else "error")
        self.estado.add_css_class("error" if error else "dato")
        self.estado.set_text(texto)

    def al_idioma_propio(self, combo, _param):
        elegido = combo.get_selected()
        if elegido == self.propio_pintado:
            return
        anterior, self.propio_pintado = self.propio_pintado, elegido
        loc = self.codigos[elegido]
        _ = self._

        def hecho(codigo):
            if codigo:
                # Cancelar el diálogo de polkit no es un error: se vuelve al de antes sin avisos.
                self.propio_pintado = anterior
                combo.set_selected(anterior)
                self.avisar("" if codigo == "cancelado" else self.motivo(codigo))
            else:
                self.avisar(_("se aplica al volver a entrar."), error=False)
        self.en_hilo(lambda: poner_idioma_propio(loc, self.yo.pw_name), hecho)

    def al_idioma_equipo(self, combo, _param):
        elegido = combo.get_selected()
        if elegido == self.equipo_pintado or elegido >= len(self.idiomas):
            return
        anterior, self.equipo_pintado = self.equipo_pintado, elegido
        loc = self.idiomas[elegido][0]
        _ = self._

        def hecho(codigo):
            if codigo:
                self.equipo_pintado = anterior
                combo.set_selected(anterior)
                self.avisar("" if codigo == "cancelado" else self.motivo(codigo))
            else:
                self.avisar(_("idioma del equipo cambiado: se aplica del todo al reiniciar."), error=False)
        self.avisar(_("cambiando el idioma del equipo…"), error=False)
        self.en_hilo(lambda: administrar(HELPER, ["idioma-equipo", loc]), hecho)

    def al_zona(self, zona):
        anterior = self.zona_pintada

        def hecho(codigo):
            if codigo:
                self.selector.poner_zona(anterior)
                if codigo != "cancelado":
                    self.avisar(self.motivo(codigo))
            else:
                self.zona_pintada = zona
                self.avisar("")
        self.avisar("")
        self.en_hilo(lambda: administrar(HELPER, ["zona", zona]), hecho)
