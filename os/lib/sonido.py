# Command OS — sonido y brillo sin ventanas: los usan Ajustes (lib/ajustes_sonido.py, ajustes_pantalla.py)
# y el centro de control (lib/centro.py). Volumen y silencio con pamixer (lo mismo que las teclas y la
# barra), el dispositivo de salida y de entrada con pactl (PipeWire) y el brillo con brightnessctl, que
# pasa por logind: la sesión activa no necesita root. docs/notas/escritorio.md § «Ajustes y centro de control».
import glob
import os
import subprocess

BRILLO_MINIMO = 5  # % : a 0 la pantalla se queda negra y no se ve dónde subirlo


def orden(*args, tiempo=5):
    """(código, salida) de una orden; (1, '') si no se puede lanzar."""
    try:
        r = subprocess.run(list(args), capture_output=True, text=True, timeout=tiempo)
    except (OSError, subprocess.SubprocessError):
        return 1, ""
    return r.returncode, r.stdout.strip()


def numero(texto, defecto=None):
    try:
        return int(texto)
    except ValueError:
        return defecto


# ---- Volumen (pamixer) ---------------------------------------------------------------------------

def volumen(entrada=False):
    """(porcentaje, silenciado) de la salida (o de la entrada) de serie; None si no hay sonido."""
    lado = ["--default-source"] if entrada else []
    # pamixer sale con 1 cuando el valor es 0 o «false»: vale lo que escribe, no el código de salida.
    nivel = orden("pamixer", *lado, "--get-volume")[1]
    if not nivel.isdigit():
        return None
    silencio = orden("pamixer", *lado, "--get-mute")[1] == "true"
    return numero(nivel), silencio


def poner_volumen(nivel, entrada=False):
    lado = ["--default-source"] if entrada else []
    return orden("pamixer", *lado, "--set-volume", str(max(0, min(100, int(nivel)))))[0] == 0


def silenciar(si, entrada=False):
    lado = ["--default-source"] if entrada else []
    return orden("pamixer", *lado, "--mute" if si else "--unmute")[0] == 0


# ---- Dispositivos (pactl) ------------------------------------------------------------------------

def dispositivos(entrada=False):
    """([(nombre interno, descripción)], el de serie). Las entradas, sin los «monitor» (el sonido que
    sale por un altavoz, no un micrófono)."""
    # La salida de texto con LC_ALL=C (claves en inglés), no la JSON: pactl 17 escribe «(null)» en las
    # descripciones con tildes («Estéreo analógico», que PipeWire da en el idioma de la sesión).
    tipo = "sources" if entrada else "sinks"
    rc, salida = orden("env", "LC_ALL=C", "pactl", "list", tipo)
    datos = []
    for linea in salida.splitlines() if rc == 0 else []:
        linea = linea.strip()
        if linea.startswith(("Sink #", "Source #")):
            datos.append({})
        elif datos and linea.startswith(("Name: ", "Description: ")):
            clave, _sep, valor = linea.partition(": ")
            datos[-1].setdefault(clave, valor)
    lista = [(d["Name"], d.get("Description") or d["Name"]) for d in datos
             if d.get("Name") and not (entrada and d["Name"].endswith(".monitor"))]
    serie = orden("pactl", "get-default-source" if entrada else "get-default-sink")[1]
    return lista, serie


def poner_dispositivo(nombre, entrada=False):
    return orden("pactl", "set-default-source" if entrada else "set-default-sink", nombre)[0] == 0


# ---- Brillo (brightnessctl) ----------------------------------------------------------------------

def hay_brillo():
    """Si la pantalla deja cambiar el brillo (un portátil: sí; un monitor externo o una VM: no)."""
    return bool(glob.glob(os.path.join(os.environ.get("COMMAND_OS_BACKLIGHT", "/sys/class/backlight"), "*")))


def brillo():
    """El brillo en %, o None si no se puede leer. `brightnessctl -m`: nombre,clase,actual,porcentaje,máximo."""
    if not hay_brillo():
        return None
    rc, salida = orden("brightnessctl", "-m", "-c", "backlight")
    partes = salida.splitlines()[0].split(",") if rc == 0 and salida else []
    return numero(partes[3].rstrip("%"), None) if len(partes) >= 4 else None


def poner_brillo(nivel):
    nivel = max(BRILLO_MINIMO, min(100, int(nivel)))
    return orden("brightnessctl", "-q", "-c", "backlight", "set", f"{nivel}%")[0] == 0
