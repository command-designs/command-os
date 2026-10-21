# Command OS — Ajustes → cuentas (lib/ajustes.py). Para quien usa el equipo: cambiar su contraseña (el
# idioma de la cuenta y la zona horaria están en «idioma y hora», lib/ajustes_idioma.py). Para un
# administrador además: ver las cuentas, añadir, borrar, dar o quitar el permiso de administrar y
# poner otra contraseña a una cuenta.
#
# Lo que necesita root lo hace lib/gestionar-cuentas, lanzado con pkexec: polkit pide la contraseña de
# un administrador (agente de polkit de la sesión) y el panel nunca la ve. Las contraseñas nuevas van
# por la entrada estándar de esa orden, nunca como argumento. La contraseña propia se cambia con
# `passwd` en un pseudoterminal (sin root: PAM comprueba la actual). docs/cuentas.md.
import grp
import os
import pty
import pwd
import select
import time

from ajustes_idioma import idiomas
from comun import (
    CONF, Dialogo, Seccion, boton, leer, problema_clave, texto_clave_corta, texto_usuario_invalido, usuario_desde,
    usuario_valido,
)
from comun import administrar as administrar_con
from gi.repository import Gtk

HELPER = "/usr/lib/command-os/gestionar-cuentas"
UID_MIN, UID_MAX = 1000, 60000
ESPERA_PASSWD = 30  # segundos


def cuentas():
    """Las cuentas de personas: uid 1000..59999 y un shell de verdad (como lib/gestionar-cuentas)."""
    lista = []
    for p in pwd.getpwall():
        if UID_MIN <= p.pw_uid < UID_MAX and not p.pw_shell.endswith(("nologin", "false")):
            lista.append(p)
    return sorted(lista, key=lambda p: p.pw_uid)


def administradores():
    try:
        wheel = grp.getgrnam("wheel")
    except KeyError:
        return set()
    return set(wheel.gr_mem) | {p.pw_name for p in pwd.getpwall() if p.pw_gid == wheel.gr_gid}


def nombre_de(p):
    return p.pw_gecos.split(",")[0].strip()


def administrar(args, entrada=""):
    """lib/gestionar-cuentas con pkexec (comun.administrar)."""
    return administrar_con(HELPER, args, entrada)


def cambiar_clave_propia(actual, nueva):
    """Cambia la contraseña de esta cuenta con `passwd` en un pseudoterminal (PAM comprueba la actual).
    LC_ALL=C: así los avisos de passwd salen siempre igual. None si fue bien o un código de error."""
    respuestas = [actual, nueva, nueva]
    pid, fd = pty.fork()
    if pid == 0:
        os.environ["LC_ALL"] = "C"
        try:
            os.execvp("passwd", ["passwd"])
        finally:
            os._exit(127)
    salida = pendiente = ""
    limite = time.monotonic() + ESPERA_PASSWD
    while time.monotonic() < limite:
        listo, _w, _x = select.select([fd], [], [], 1)
        if not listo:
            continue
        try:
            datos = os.read(fd, 1024)
        except OSError:
            break
        if not datos:
            break
        texto = datos.decode(errors="replace")
        salida += texto
        pendiente += texto
        # Cada petición termina en «: » (Current password: / New password: / Retype new password:).
        if respuestas and pendiente.rstrip().endswith(":"):
            os.write(fd, (respuestas.pop(0) + "\n").encode())
            pendiente = ""
    else:
        os.kill(pid, 9)
    os.close(fd)
    _pid, estado = os.waitpid(pid, 0)
    if os.WIFEXITED(estado) and os.WEXITSTATUS(estado) == 0:
        return None
    return "actual_incorrecta" if "uthentication" in salida else "fallo"


class Pagina(Seccion):
    def __init__(self, ventana, traducir):
        super().__init__(ventana, traducir)
        self.yo = pwd.getpwuid(os.getuid())
        self.idiomas = idiomas()
        self.pintar()

    def al_mostrar(self):
        self.pintar()  # las cuentas pueden haber cambiado fuera (otra sesión, la terminal)

    # ---- Textos ------------------------------------------------------------------------------

    def motivo(self, codigo):
        _ = self._
        return {
            "usuario_invalido": texto_usuario_invalido(_),
            "usuario_existe": _("ya existe una cuenta con ese usuario."),
            "nombre_reservado": _("ese nombre está reservado por el sistema: elige otro."),
            "nombre_invalido": _("el nombre no puede llevar «:»."),
            "clave_corta": texto_clave_corta(_),
            "es_la_propia": _("no se puede hacer con tu propia cuenta."),
            "sesion_abierta": _("esa cuenta tiene la sesión abierta: cierra la sesión antes."),
            "ultimo_admin": _("tiene que quedar al menos una cuenta administradora."),
            "no_existe": _("esa cuenta ya no existe."),
            "idioma_no_disponible": _("ese idioma no está disponible."),
            "autenticacion": _("no se pudo comprobar la contraseña de administrador."),
            "actual_incorrecta": _("la contraseña actual no es correcta."),
        }.get(codigo, _("no se pudo completar la operación."))

    # ---- Pintado -----------------------------------------------------------------------------

    def pintar(self, aviso=""):
        _ = self._
        self.limpiar()
        self.titulo(_("› cuentas"))
        admins = administradores()
        soy_admin = self.yo.pw_name in admins

        # Mi cuenta.
        self.etiqueta(_("mi cuenta"))
        quien = nombre_de(self.yo) or self.yo.pw_name
        rol = _("administrador") if soy_admin else _("cuenta normal")
        self.nota(f"{quien} · {self.yo.pw_name} · {rol}", "dato")
        self.caja.append(self.boton_clave())

        # Las cuentas del equipo.
        cabecera = Gtk.Box(spacing=12)
        lista_t = Gtk.Label(label=_("cuentas del equipo").upper(), xalign=0, hexpand=True)
        lista_t.add_css_class("etiqueta")
        cabecera.append(lista_t)
        if soy_admin:
            nueva = boton(_("añadir cuenta"))
            nueva.connect("clicked", self.al_anadir)
            cabecera.append(nueva)
        self.caja.append(cabecera)
        self.caja.append(self.lista(admins, soy_admin))

        self.estado = self.nota(aviso, "error")

    def boton_clave(self):
        _ = self._
        b = boton(_("cambiar mi contraseña"), halign=Gtk.Align.START)
        b.connect("clicked", self.al_cambiar_clave)
        return b

    def lista(self, admins, soy_admin):
        _ = self._
        principal = leer(f"{CONF}/cuenta-principal")
        caja = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=6)
        for p in cuentas():
            linea = Gtk.Box(spacing=10)
            texto = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
            nombre = Gtk.Label(label=nombre_de(p) or p.pw_name, xalign=0)
            etiquetas = [p.pw_name]
            if p.pw_name in admins:
                etiquetas.append(_("administrador"))
            if p.pw_name == self.yo.pw_name:
                etiquetas.append(_("tú"))
            elif p.pw_name == principal:
                etiquetas.append(_("principal"))
            detalle = Gtk.Label(label=" · ".join(etiquetas), xalign=0)
            detalle.add_css_class("tenue")
            texto.append(nombre)
            texto.append(detalle)
            texto.set_hexpand(True)
            linea.append(texto)
            if soy_admin and p.pw_name != self.yo.pw_name:
                quitar = p.pw_name in admins
                b_admin = boton(_("quitar admin") if quitar else _("hacer admin"))
                b_admin.add_css_class("flat")
                b_admin.connect("clicked", self.al_admin, p.pw_name, not quitar)
                b_clave = boton(_("contraseña"))
                b_clave.add_css_class("flat")
                b_clave.connect("clicked", self.al_clave_ajena, p.pw_name)
                b_borrar = boton(_("borrar"))
                b_borrar.add_css_class("flat")
                b_borrar.connect("clicked", self.al_borrar, p.pw_name)
                for b in (b_admin, b_clave, b_borrar):
                    linea.append(b)
            caja.append(linea)
        return caja

    # ---- Mi contraseña ----------------------------------------------------------------------------

    def al_cambiar_clave(self, _boton):
        _ = self._
        campos = [
            ("actual", _("contraseña actual"), "clave", None),
            ("nueva", _("contraseña nueva"), "clave", None),
            ("repetir", _("repítela"), "clave", None),
        ]
        Dialogo(self.ventana, _("cambiar mi contraseña"), "", campos, _("cambiar"), self.hacer_clave_propia, _).present()

    def hacer_clave_propia(self, dialogo, v):
        _ = self._
        if problema := problema_clave(v["nueva"], v["repetir"], _):
            return problema

        def hecho(codigo):
            if codigo:
                dialogo.mostrar_error(self.motivo(codigo))
            else:
                dialogo.close()
                self.pintar(_("contraseña cambiada."))
                self.estado.remove_css_class("error")
                self.estado.add_css_class("dato")
        self.en_hilo(lambda: cambiar_clave_propia(v["actual"], v["nueva"]), hecho)
        return None

    # ---- Administrar cuentas ------------------------------------------------------------------------

    def tras_administrar(self, codigo, aviso_ok=""):
        if codigo:
            self.pintar("" if codigo == "cancelado" else self.motivo(codigo))
        else:
            self.pintar()
            if aviso_ok:
                self.estado.remove_css_class("error")
                self.estado.add_css_class("dato")
                self.estado.set_text(aviso_ok)

    def al_admin(self, _boton, usuario, si):
        self.en_hilo(lambda: administrar(["admin", usuario, "si" if si else "no"]), self.tras_administrar)

    def al_borrar(self, _boton, usuario):
        _ = self._
        campos = [("conservar", _("conservar su carpeta personal"), "interruptor", None)]
        intro = _("se borrará la cuenta {usuario}. no se puede deshacer.").format(usuario=usuario)

        def aceptar(dialogo, v):
            args = ["borrar", usuario] + (["--conservar-home"] if v["conservar"] else [])

            def hecho(codigo):
                if codigo:
                    dialogo.mostrar_error("" if codigo == "cancelado" else self.motivo(codigo))
                else:
                    dialogo.close()
                    self.tras_administrar(None, _("cuenta {usuario} borrada.").format(usuario=usuario))
            self.en_hilo(lambda: administrar(args), hecho)
            return None
        Dialogo(self.ventana, _("borrar cuenta"), intro, campos, _("borrar"), aceptar, _).present()

    def al_clave_ajena(self, _boton, usuario):
        _ = self._
        campos = [
            ("nueva", _("contraseña nueva"), "clave", None),
            ("repetir", _("repítela"), "clave", None),
        ]

        def aceptar(dialogo, v):
            if problema := problema_clave(v["nueva"], v["repetir"], _):
                return problema

            def hecho(codigo):
                if codigo:
                    dialogo.mostrar_error("" if codigo == "cancelado" else self.motivo(codigo))
                else:
                    dialogo.close()
                    self.tras_administrar(None, _("contraseña de {usuario} cambiada.").format(usuario=usuario))
            self.en_hilo(lambda: administrar(["clave", usuario], v["nueva"] + "\n"), hecho)
            return None
        intro = _("contraseña nueva para {usuario}.").format(usuario=usuario)
        Dialogo(self.ventana, _("contraseña de otra cuenta"), intro, campos, _("cambiar"), aceptar, _).present()

    def al_anadir(self, _boton):
        _ = self._
        nombres = [_("el del equipo")] + [n for _loc, n in self.idiomas]
        codigos = [""] + [loc for loc, _n in self.idiomas]
        campos = [
            ("nombre", _("tu nombre"), "texto", None),
            ("usuario", _("usuario"), "texto", None),
            ("nueva", _("contraseña"), "clave", None),
            ("repetir", _("repítela"), "clave", None),
            ("admin", _("puede administrar el equipo"), "interruptor", None),
            ("idioma", _("idioma de la cuenta"), "lista", nombres),
        ]

        def aceptar(dialogo, v):
            usuario = v["usuario"].strip() or usuario_desde(v["nombre"])
            if not usuario_valido(usuario):
                return texto_usuario_invalido(_)
            if problema := problema_clave(v["nueva"], v["repetir"], _):
                return problema
            args = ["anadir", usuario]
            if v["nombre"].strip():
                args += ["--nombre", v["nombre"].strip()]
            if v["admin"]:
                args.append("--admin")
            if codigos[v["idioma"]]:
                args += ["--idioma", codigos[v["idioma"]]]

            def hecho(codigo):
                if codigo:
                    dialogo.mostrar_error("" if codigo == "cancelado" else self.motivo(codigo))
                else:
                    dialogo.close()
                    self.tras_administrar(None, _("cuenta {usuario} creada.").format(usuario=usuario))
            self.en_hilo(lambda: administrar(args, v["nueva"] + "\n"), hecho)
            return None
        d = Dialogo(self.ventana, _("añadir cuenta"), "", campos, _("crear cuenta"), aceptar, _)
        d.present()

