# Command OS — Ajustes → wi-fi y red (lib/ajustes.py). El wi-fi (lib/redes.py: encender, elegir red y
# contraseña en dos pasos, desconectar y olvidar) y el estado de la red por cable. Lo raro (redes
# ocultas, empresa, VPN, IP fija), en «avanzado»: nm-connection-editor.
import red
from comun import Seccion
from redes import ListaRedes


class Pagina(Seccion):
    def __init__(self, ventana, traducir):
        super().__init__(ventana, traducir)
        _ = self._
        self.titulo(_("› wi-fi y red"))
        self.redes = ListaRedes(_, completa=True, filas=8, al_cambiar=self.pintar_cable)
        self.caja.append(self.redes)
        self.etiqueta(_("por cable"))
        self.cable = self.nota("")
        self.pintar_cable()
        self.avanzado([(_("redes ocultas, vpn, ip fija y el resto de la red"), ["nm-connection-editor"])])

    def al_mostrar(self):
        self.redes.al_dia()
        self.pintar_cable()

    def pintar_cable(self):
        _ = self._
        estado = red.cable()
        if estado is None:
            self.cable.set_text(_("este equipo no tiene red por cable."))
        elif estado[0]:
            self.cable.set_text(_("conectado ({red}).").format(red=estado[1]))
        else:
            self.cable.set_text(_("sin cable conectado."))
