#!/usr/bin/env python3
"""Command OS — los menús de labwc en la sesión de Hyprland, que no tiene (docs/notas/escritorio.md
§ «Sesión Hyprland de prueba»). Lee el mismo menu.xml, traducido como en lib/menus-labwc, y lo enseña
con wofi junto al puntero, con el aspecto de los paneles pequeños (wofi/power.css). Un submenú abre otro
panel en el mismo sitio. Las acciones de ventana van a hyprland.lua (command_os.boton y command_os.enviar).
Lo lanza hyprland.lua (command_os.menu) con el puntero y el tamaño de lo que deja libre la barra.

    menu-hyprland.py escritorio|ventana X Y ANCHO ALTO   abre el menú del escritorio o el de ventana
    menu-hyprland.py --seco escritorio|ventana            cada entrada con su orden, sin abrir nada (tests)
"""
import os
import shlex
import subprocess
import sys
import xml.etree.ElementTree as ET

sys.path.insert(0, os.path.dirname(os.path.realpath(__file__)))
from traducir import etiquetas  # noqa: E402

MENU = os.environ.get("COMMAND_OS_MENU", "/usr/share/command-os/config/labwc/menu.xml")
IDS = {"escritorio": "root-menu", "ventana": "client-menu"}
TAG = "command-os-menu"
# Medidas del panel (wofi/power.css): ancho, alto de cada opción y lo que suman el chaflán y el margen.
ANCHO, FILA, BORDES = 260, 38, 16
SUBMENU = "  ›"

# Las acciones de labwc que tienen equivalente: la orden de Hyprland. «Siempre encima» y «en todos los
# escritorios» son la misma en Hyprland (fijar): sale solo la primera.
BOTONES = {
    "Iconify": "minimizar", "ToggleMaximize": "maximizar", "ToggleFullscreen": "pantalla_completa",
    "ToggleAlwaysOnTop": "fijar", "ToggleOmnipresent": "fijar", "Close": "cerrar",
}
# Las opciones que se quedan fuera por no tener equivalente (--seco falla con ellas).
SIN_EQUIVALENTE = []


def orden(accion):
    """La orden (lista para subprocess) de una <action> de labwc, o None si no tiene equivalente."""
    nombre = accion.get("name")
    if nombre == "Execute" and accion.get("command"):
        return ["sh", "-c", accion.get("command")]
    if nombre == "Reconfigure":
        return ["hyprctl", "reload"]
    if nombre in BOTONES:
        return ["hyprctl", "eval", f"command_os.boton('{BOTONES[nombre]}')"]
    if nombre == "SendToDesktop" and (accion.get("to") or "").isdigit():
        return ["hyprctl", "eval", f"command_os.enviar({int(accion.get('to'))})"]
    return None


def entradas(menu):
    """(etiqueta, orden o submenú) de cada opción del menú, en orden; sin separadores ni repetidas."""
    lista, vistas = [], set()
    for hijo in menu:
        etiqueta = hijo.get("label")
        if hijo.tag == "item" and etiqueta:
            acciones = [orden(a) for a in hijo.findall("action")]
            if not acciones or None in acciones:
                SIN_EQUIVALENTE.append(etiqueta)
            elif repr(acciones) not in vistas:
                vistas.add(repr(acciones))
                lista.append((etiqueta, acciones))
        elif hijo.tag == "menu" and etiqueta:
            lista.append((etiqueta + SUBMENU, hijo))
    return lista


def submenu(menu):
    """Las opciones de un <menu>: las suyas o, si es de los que ejecutan algo (pipemenu), las que imprime."""
    if menu.get("execute"):
        try:
            salida = subprocess.run(shlex.split(menu.get("execute")), capture_output=True, text=True,
                                    timeout=5).stdout
            return entradas(ET.fromstring(salida))
        except (OSError, subprocess.SubprocessError, ET.ParseError):
            return []
    return entradas(menu)


def cargar(cual):
    with open(MENU, encoding="utf-8") as f:
        texto = f.read()
    try:
        texto = etiquetas(texto)
    except Exception:  # sin traducción, en castellano (como lib/menus-labwc)
        pass
    for menu in ET.fromstring(texto).iter("menu"):
        if menu.get("id") == IDS[cual]:
            return entradas(menu)
    return []


def elegir(lista, x, y, ancho, alto):
    """Enseña las etiquetas con wofi en x, y (sin salirse de la pantalla) y devuelve la elegida o None."""
    alto_panel = len(lista) * FILA + BORDES
    x = max(0, min(x, ancho - ANCHO))
    y = max(0, min(y, alto - alto_panel))
    estilo = subprocess.run(["command-os-config", "wofi/power.css"], capture_output=True,
                            text=True).stdout.strip()
    try:
        r = subprocess.run(
            ["wofi", "--dmenu", "--prompt", TAG, "--style", estilo, "--cache-file", "/dev/null",
             "--width", str(ANCHO), "--lines", str(len(lista)), "--location", "top_left",
             "--xoffset", str(x), "--yoffset", str(y)],
            input="\n".join(etiqueta for etiqueta, _ in lista), capture_output=True, text=True)
    except OSError:
        return None
    eleccion = r.stdout.rstrip("\n")
    return next((destino for etiqueta, destino in lista if etiqueta == eleccion), None)


def seco(lista, sangria=""):
    for etiqueta, destino in lista:
        if isinstance(destino, list):
            print(f"{sangria}{etiqueta}\t" + " && ".join(shlex.join(o) for o in destino))
        else:
            print(f"{sangria}{etiqueta}")
            seco(submenu(destino), sangria + "  ")


def main(args):
    if len(args) == 2 and args[0] == "--seco" and args[1] in IDS:
        seco(cargar(args[1]))
        for etiqueta in SIN_EQUIVALENTE:
            print(f"sin equivalente en Hyprland: {etiqueta}", file=sys.stderr)
        return 1 if SIN_EQUIVALENTE else 0
    if len(args) != 5 or args[0] not in IDS or not all(a.lstrip("-").isdigit() for a in args[1:]):
        print(__doc__.strip(), file=sys.stderr)
        return 2
    # Si ya hay un menú abierto, el clic lo cierra (como command-os-power).
    if subprocess.run(["pkill", "-f", f"^wofi --dmenu --prompt {TAG}"]).returncode == 0:
        return 0
    x, y, ancho, alto = (int(a) for a in args[1:])
    lista = cargar(args[0])
    while lista:
        destino = elegir(lista, x, y, ancho, alto)
        if isinstance(destino, list):
            for o in destino:
                subprocess.Popen(o, start_new_session=True, stdin=subprocess.DEVNULL,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            return 0
        lista = submenu(destino) if destino is not None else []
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
