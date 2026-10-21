#!/usr/bin/env python3
# Command OS — pide la contraseña de una red wi-fi (segundo paso de command-os-wifi) con el diálogo de los
# paneles (comun.Dialogo). Escribe la contraseña en la salida estándar y sale con 0; si se cancela, sale
# con 1 sin escribir nada. Se abre para esto y se cierra: nada se queda en memoria.
# docs/notas/escritorio.md § «Barra».
#     clave-wifi.py RED
import sys

from comun import Dialogo, cargar_tema, traductor
from gi.repository import Gtk


class App(Gtk.Application):
    def __init__(self, red):
        super().__init__(application_id="dev.commandlab.ClaveWifi")
        self.red = red
        self.clave = None

    def do_activate(self):
        _ = traductor()
        cargar_tema()

        def aceptar(dialogo, valores):
            if not valores["clave"]:
                return _("escribe la contraseña.")
            self.clave = valores["clave"]
            dialogo.close()
            return None

        dialogo = Dialogo(None, _("wi-fi"), _("contraseña de la red {red}").format(red=self.red),
                          [("clave", _("contraseña"), "clave", None)], _("conectar"), aceptar, _)
        dialogo.set_application(self)
        dialogo.present()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("uso: clave-wifi.py RED", file=sys.stderr)
        sys.exit(2)
    app = App(sys.argv[1])
    app.run([])
    if app.clave is None:
        sys.exit(1)
    print(app.clave)
