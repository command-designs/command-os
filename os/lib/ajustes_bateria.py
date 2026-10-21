# Command OS — Ajustes → batería (lib/ajustes.py; también clic derecho en la batería de la barra). Enseña
# el estado y, solo si el portátil lo permite (charge_control_end_threshold), el límite de carga al 80 %.
# Ese lo pone lib/gestionar-bateria con pkexec (la sesión activa no necesita contraseña:
# system/polkit-gestionar-bateria.policy). docs/notas/escritorio.md § «Batería».
import bateria
from comun import Seccion, administrar
from gi.repository import Gtk

HELPER = "/usr/lib/command-os/gestionar-bateria"


class Pagina(Seccion):
    def __init__(self, ventana, traducir):
        super().__init__(ventana, traducir)
        self.ocupado = False
        self.resumen = None
        self.pintar()
        self.cada(30, self.al_reloj)

    def interruptor(self, texto, activo, al_cambiar):
        fila = Gtk.Box(spacing=12)
        etiqueta = Gtk.Label(label=texto, xalign=0, hexpand=True, wrap=True, max_width_chars=44)
        fila.append(etiqueta)
        boton = Gtk.Switch(active=activo, valign=Gtk.Align.CENTER)
        boton.connect("state-set", al_cambiar)
        fila.append(boton)
        self.caja.append(fila)
        return boton

    def pintar(self, aviso="", error=True):
        _ = self._
        self.limpiar()
        self.titulo(_("› batería"))
        d = bateria.estado()
        self.resumen = None
        if d is None:
            self.nota(_("este equipo no tiene batería."))
        else:
            self.resumen = self.nota(bateria.resumen(d, _), "dato")
            if d["limite"] is not None:
                self.interruptor(_("limitar la carga al 80 %"), d["limite"] < 100, self.al_limite)
                self.nota(_("la batería dura más años si no pasa mucho tiempo al 100 %: con esto deja de cargar al "
                            "80 %. sirve sobre todo si el portátil pasa mucho tiempo enchufado; quítalo antes de un "
                            "viaje para tener la carga completa."))
        self.estado = self.nota(aviso, "error" if error else "dato")

    def al_mostrar(self):
        self.al_reloj()

    def al_reloj(self):
        d = bateria.estado()
        if d is not None and not self.ocupado and self.resumen is not None:
            self.resumen.set_text(bateria.resumen(d, self._))

    def al_limite(self, boton, activo):
        _ = self._
        if self.ocupado:
            return True
        self.ocupado = True
        boton.set_sensitive(False)

        def hecho(codigo):
            self.ocupado = False
            if codigo is None:
                self.pintar(_("la carga se para en el 80 %.") if activo else _("la batería vuelve a cargar hasta el 100 %."),
                            error=False)
            elif codigo == "cancelado":
                self.pintar()
            else:
                self.pintar({
                    "rechazado": _("el portátil no aceptó el límite de carga."),
                    "no_soportado": _("este portátil no permite limitar la carga."),
                    "autenticacion": _("no se pudo comprobar la contraseña de administrador."),
                }.get(codigo, _("no se pudo completar la operación.")))
        self.en_hilo(lambda: administrar(HELPER, ["limite", "80" if activo else "no"]), hecho)
        return True  # el interruptor se repinta con el estado real al terminar
