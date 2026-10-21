# Command OS — Ajustes → pantalla (lib/ajustes.py). El brillo (solo si la pantalla lo permite: un
# portátil sí, un monitor externo o una VM no) y el tamaño de todo (la escala: automática según la
# densidad de la pantalla, o fija). Resolución, posición y varias pantallas, en «avanzado» (wdisplays).
# La escala la aplica command-os-pantallas (lib/pantallas.py, docs/notas/pantallas.md).
import os
import subprocess

import sonido
from comun import Deslizador, Seccion, fila
from gi.repository import Gtk

ESCALAS = ["auto", "1", "1.25", "1.5", "1.75", "2"]


def archivo_escala():
    return os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"), "command-os", "escala")


def escala_elegida():
    """La de ~/.config/command-os/escala si es una de ESCALAS; si no, la automática."""
    try:
        with open(archivo_escala(), encoding="utf-8") as f:
            valor = f.read().strip().replace(",", ".")
    except OSError:
        return "auto"
    for e in ESCALAS[1:]:
        try:
            if abs(float(valor) - float(e)) < 0.01:
                return e
        except ValueError:
            break
    return "auto"


def poner_escala(valor):
    try:
        os.makedirs(os.path.dirname(archivo_escala()), exist_ok=True)
        with open(archivo_escala(), "w", encoding="utf-8") as f:
            f.write(f"{valor}\n")
        subprocess.run(["command-os-pantallas", "aplicar"], capture_output=True, timeout=20)
    except (OSError, subprocess.SubprocessError):
        return False
    return True


class Pagina(Seccion):
    def __init__(self, ventana, traducir):
        super().__init__(ventana, traducir)
        _ = self._
        self.titulo(_("› pantalla"))
        self.brillo = None
        nivel = sonido.brillo()
        if nivel is not None:
            self.brillo = Deslizador("display-brightness-symbolic", nivel, sonido.poner_brillo,
                                     minimo=sonido.BRILLO_MINIMO)
            self.caja.append(fila(_("brillo"), self.brillo))
        nombres = [_("automático, según la pantalla")] + [f"{int(float(e) * 100)} %" for e in ESCALAS[1:]]
        self.combo = Gtk.DropDown.new_from_strings(nombres)
        self.pintada = ESCALAS.index(escala_elegida())
        self.combo.set_selected(self.pintada)
        self.combo.connect("notify::selected", self.al_escala)
        self.caja.append(fila(_("tamaño de textos y ventanas"), self.combo))
        self.estado = self.nota(_("automático: más grande en pantallas de mucha densidad, como las de los portátiles "
                                  "pequeños de alta resolución."))
        self.avanzado([(_("resolución, posición y varias pantallas"), ["wdisplays"])])
        self.cada(3, self.al_dia)

    def al_mostrar(self):
        self.al_dia()

    def al_dia(self):
        """El brillo, por si se ha cambiado con las teclas."""
        if self.brillo is not None and self.brillo.pendiente is None:
            nivel = sonido.brillo()
            if nivel is not None:
                self.brillo.poner(nivel)

    def al_escala(self, combo, _param):
        i = combo.get_selected()
        if i == self.pintada:
            return
        self.pintada = i
        _ = self._
        self.estado.set_text(_("aplicando…"))
        self.en_hilo(lambda: poner_escala(ESCALAS[i]),
                     lambda bien: self.estado.set_text(_("hecho.") if bien else _("no se pudo cambiar el tamaño.")))
