# Command OS — el Bluetooth con bluetoothctl, sin ventanas (se llama bt.py: «bluetooth» es el nombre de
# otra biblioteca de Python). Lo usan Ajustes → bluetooth (lib/ajustes_bluetooth.py) y el centro de
# control (lib/centro.py): encender o apagar y los dispositivos emparejados (conectar, desconectar,
# olvidar). Emparejar uno nuevo se hace en blueman («avanzado»): su applet ya es el agente que contesta al
# PIN. docs/notas/escritorio.md § «Bluetooth».
import glob
import os
import re
import subprocess

MAC = re.compile(r"^[0-9A-F]{2}(:[0-9A-F]{2}){5}$")


def adaptador():
    """Si hay adaptador. Se mira en /sys: sin adaptador, `bluetoothctl show` se queda esperando."""
    return bool(glob.glob(os.path.join(os.environ.get("COMMAND_OS_BLUETOOTH_SYS", "/sys/class/bluetooth"), "hci*")))


def ctl(*args, tiempo=10):
    """(código, salida) de bluetoothctl; (1, '') si no se puede lanzar o tarda demasiado."""
    try:
        r = subprocess.run(["bluetoothctl", *args], capture_output=True, text=True, timeout=tiempo)
    except (OSError, subprocess.SubprocessError):
        return 1, ""
    return r.returncode, r.stdout


def encendido():
    return adaptador() and "Powered: yes" in ctl("show", tiempo=3)[1]


def poner(encender):
    """Enciende (quitando antes el bloqueo de rfkill, que la sesión activa puede tocar sin root) o apaga."""
    if not adaptador():
        return False
    if encender:
        try:
            subprocess.run(["rfkill", "unblock", "bluetooth"], capture_output=True, timeout=5)
        except (OSError, subprocess.SubprocessError):
            pass
    return ctl("power", "on" if encender else "off")[0] == 0


def dispositivos():
    """Los emparejados: [{mac, nombre, conectado, icono}], los conectados primero."""
    if not adaptador():
        return []
    _rc, salida = ctl("devices", "Paired", tiempo=5)
    lista = []
    for linea in salida.splitlines():
        partes = linea.split(" ", 2)
        if len(partes) < 2 or partes[0] != "Device" or not MAC.match(partes[1]):
            continue
        info = ctl("info", partes[1], tiempo=5)[1]
        icono = re.search(r"^\s*Icon: (\S+)", info, re.M)
        lista.append({
            "mac": partes[1],
            "nombre": partes[2] if len(partes) > 2 else partes[1],
            "conectado": re.search(r"^\s*Connected: yes", info, re.M) is not None,
            "icono": icono.group(1) if icono else "bluetooth",
        })
    return sorted(lista, key=lambda d: (not d["conectado"], d["nombre"].lower()))


def conectados():
    return sum(1 for d in dispositivos() if d["conectado"])


def accion(orden, mac):
    """connect, disconnect o remove (olvidar) sobre un dispositivo. True si fue bien."""
    if orden not in ("connect", "disconnect", "remove") or not MAC.match(mac):
        return False
    rc, salida = ctl(orden, mac, tiempo=25)
    return rc == 0 and "Failed" not in salida
