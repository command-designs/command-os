# Command OS — la red con nmcli, sin ventanas: la usan Ajustes → wi-fi y red (lib/ajustes_red.py) y el
# centro de control (lib/centro.py), con la lista de redes de lib/redes.py.
#
# Redes: la conectada primero y luego de más a menos señal, una vez cada nombre (varios puntos de acceso
# de la misma red salen juntos) y sin las ocultas, que van en «avanzado» (nm-connection-editor). Una red
# guardada (perfil con su nombre) entra sin preguntar; si su contraseña ya no vale, se pide otra. La
# contraseña llega a nmcli por la entrada estándar (--ask), nunca en la línea de órdenes, donde la
# vería cualquiera con ps. docs/notas/escritorio.md § «Ajustes y centro de control».
import subprocess

ESPERA = 30  # segundos que nmcli espera a que la conexión quede hecha


def nmcli(*args, entrada=None, tiempo=ESPERA + 15):
    """(código de salida, salida) de nmcli; (1, '') si no se puede lanzar."""
    try:
        r = subprocess.run(["nmcli", *args], input=entrada, capture_output=True, text=True, timeout=tiempo)
    except (OSError, subprocess.SubprocessError):
        return 1, ""
    return r.returncode, r.stdout


def campos(linea, n):
    """Los n campos de una línea de `nmcli -t -e no`: el último (el nombre) puede llevar «:»."""
    partes = linea.split(":", n - 1)
    return partes if len(partes) == n else None


def dispositivo_wifi():
    """El nombre de la tarjeta wi-fi (wlan0…) o None si el equipo no tiene."""
    _rc, salida = nmcli("-t", "-e", "no", "-f", "DEVICE,TYPE", "device", tiempo=10)
    for linea in salida.splitlines():
        c = campos(linea, 2)
        if c and c[1] == "wifi":
            return c[0]
    return None


def wifi_encendido():
    return nmcli("radio", "wifi", tiempo=10)[1].strip() == "enabled"


def poner_wifi(encendido):
    return nmcli("radio", "wifi", "on" if encendido else "off", tiempo=15)[0] == 0


def conexion():
    """La red de verdad conectada: ('wifi', nombre), ('ethernet', nombre) o None."""
    _rc, salida = nmcli("-t", "-e", "no", "-f", "TYPE,STATE,CONNECTION", "device", tiempo=10)
    for linea in salida.splitlines():
        c = campos(linea, 3)
        if c and c[0] in ("wifi", "ethernet") and c[1] == "connected":
            return c[0], c[2]
    return None


def cable():
    """La red por cable: None si el equipo no tiene tarjeta de cable; si no, (conectado, nombre)."""
    _rc, salida = nmcli("-t", "-e", "no", "-f", "TYPE,STATE,CONNECTION", "device", tiempo=10)
    hay = None
    for linea in salida.splitlines():
        c = campos(linea, 3)
        if c and c[0] == "ethernet":
            if c[1] == "connected":
                return True, c[2]
            hay = (False, "")
    return hay


def guardadas():
    """Los nombres de los perfiles wi-fi guardados."""
    _rc, salida = nmcli("-t", "-e", "no", "-f", "TYPE,NAME", "connection", "show", tiempo=10)
    nombres = set()
    for linea in salida.splitlines():
        c = campos(linea, 2)
        if c and c[0] in ("802-11-wireless", "wifi"):  # en modo -t, el nombre largo del tipo
            nombres.add(c[1])
    return nombres


def senal_nivel(senal):
    """0 a 4, para el icono (las mismas rayas que la barra)."""
    return 4 if senal >= 80 else 3 if senal >= 60 else 2 if senal >= 40 else 1 if senal >= 20 else 0


def redes(buscar=False):
    """[{nombre, senal, seguridad, segura, conectada, guardada}] por orden: la conectada y luego por señal.
    buscar: pide a la tarjeta que vuelva a mirar (tarda unos segundos)."""
    _rc, salida = nmcli("-t", "-e", "no", "-f", "IN-USE,SIGNAL,SECURITY,SSID", "device", "wifi", "list",
                        "--rescan", "yes" if buscar else "auto", tiempo=40)
    vistas = {}
    for linea in salida.splitlines():
        c = campos(linea, 4)
        if not c or not c[3]:
            continue  # las ocultas no tienen nombre
        uso, senal, seguridad, nombre = c
        senal = int(senal) if senal.isdigit() else 0
        red = {"nombre": nombre, "senal": senal, "seguridad": seguridad, "segura": seguridad not in ("", "--"),
               "conectada": uso == "*"}
        antes = vistas.get(nombre)
        if antes is None:
            vistas[nombre] = red
        else:
            antes["conectada"] = antes["conectada"] or red["conectada"]
            antes["senal"] = max(antes["senal"], red["senal"])
    con_perfil = guardadas() if vistas else set()
    for red in vistas.values():
        red["guardada"] = red["nombre"] in con_perfil
    return sorted(vistas.values(), key=lambda r: (not r["conectada"], -r["senal"], r["nombre"].lower()))


def conectar(red, clave=None):
    """Conecta a una red de redes(). Devuelve None si quedó conectada, `necesita_clave` si hay que pedir
    la contraseña (red segura nueva, o guardada cuya contraseña ya no vale) o `fallo`."""
    dispositivo = dispositivo_wifi()
    if dispositivo is None:
        return "sin_wifi"
    nombre = red["nombre"]
    if clave is None:
        if red.get("guardada"):
            if nmcli("--wait", str(ESPERA), "connection", "up", "id", nombre)[0] == 0:
                return None
            return "necesita_clave" if red["segura"] else "fallo"
        if red["segura"]:
            return "necesita_clave"
        rc, _s = nmcli("--wait", str(ESPERA), "device", "wifi", "connect", nombre, "ifname", dispositivo)
        return None if rc == 0 else "fallo"
    entrada = clave + "\n"
    if red.get("guardada"):
        rc, _s = nmcli("--ask", "--wait", str(ESPERA), "connection", "up", "id", nombre, entrada=entrada)
    else:
        rc, _s = nmcli("--ask", "--wait", str(ESPERA), "device", "wifi", "connect", nombre, "ifname", dispositivo,
                       entrada=entrada)
    return None if rc == 0 else "fallo"


def desconectar():
    dispositivo = dispositivo_wifi()
    return dispositivo is not None and nmcli("device", "disconnect", dispositivo, tiempo=20)[0] == 0


def olvidar(nombre):
    """Borra el perfil guardado de una red (la contraseña con él)."""
    return nmcli("connection", "delete", "id", nombre, tiempo=20)[0] == 0
