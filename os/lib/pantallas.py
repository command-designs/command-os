#!/usr/bin/env python3
"""Command OS — escala de las pantallas (docs/notas/pantallas.md). Lo usa command-os-pantallas.

  pantallas.py escala ANCHO ALTO ANCHO_MM ALTO_MM [NOMBRE]   escala automática de esa pantalla
  pantallas.py aplicar                                        ajusta la escala de cada pantalla
  pantallas.py vigilar                                        igual al conectar una pantalla nueva
  pantallas.py lista                                          NOMBRE ANCHO ALTO ESCALA de las encendidas
  pantallas.py hyprlock CONFIGURACIÓN                         la de hyprlock, escalada por pantalla

La escala sale de la densidad (píxeles por pulgada, del tamaño físico que da el monitor) en pasos
de 0,25, con un tope para que el área útil no baje de 720 px de alto. Sin tamaño fiable (VM,
proyectores, televisores que solo dan la proporción) se queda en 1. Se puede fijar a mano con un
número o «auto» en ~/.config/command-os/escala (la cuenta) o /etc/command-os/escala (todo el
equipo, también la pantalla de inicio de sesión y el asistente); el tope de alto útil se respeta.
"""
import json
import math
import os
import re
import subprocess
import sys
import time

# Paneles internos (portátiles, el cyberdeck): se miran más de cerca que un monitor de mesa.
INTERNAS = ("eDP", "LVDS", "DSI")
PPP_INTERNA = 120  # densidad a la que un panel interno se ve bien a escala 1
PPP_EXTERNA = 110
ALTO_MINIMO = 720  # área útil mínima (alto lógico) para que quepan las ventanas de serie
ESCALA_MAX = 3.0
VIGILAR_CADA = 2  # segundos


def escala_auto(ancho, alto, ancho_mm, alto_mm, nombre=""):
    if ancho <= 0 or alto <= 0:
        return 1.0
    # Tamaño no fiable: sin dato, demasiado pequeño para ser real o con otra proporción que los
    # píxeles (hay monitores que dan 16x9 «cm» como proporción, no como tamaño).
    if ancho_mm < 100 or alto_mm < 60 or abs((ancho / alto) / (ancho_mm / alto_mm) - 1) > 0.2:
        return 1.0
    ppp = ancho / (ancho_mm / 25.4)
    ref = PPP_INTERNA if nombre.startswith(INTERNAS) else PPP_EXTERNA
    escala = math.floor(ppp / ref * 4 + 0.5) / 4
    tope = math.floor(alto / ALTO_MINIMO * 4) / 4
    return max(1.0, min(escala, tope, ESCALA_MAX))


def preferencia():
    """Escala fijada a mano (número entre 1 y 3) o None para la automática."""
    rutas = [os.path.join(os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config"),
                          "command-os", "escala"), "/etc/command-os/escala"]
    for ruta in rutas:
        try:
            with open(ruta, encoding="utf-8") as f:
                valor = f.read().strip().replace(",", ".")
        except OSError:
            continue
        if valor in ("", "auto"):
            return None
        try:
            return min(ESCALA_MAX, max(1.0, float(valor)))
        except ValueError:
            print(f"command-os-pantallas: valor no válido en {ruta}: {valor!r}", file=sys.stderr)
            return None
    return None


def salidas():
    r = subprocess.run(["wlr-randr", "--json"], capture_output=True, text=True, timeout=10)
    if r.returncode != 0:
        raise ConnectionError(r.stderr.strip())
    lista = []
    for s in json.loads(r.stdout):
        modo = next((m for m in s.get("modes", []) if m.get("current")), None)
        if not s.get("enabled") or modo is None:
            continue
        # El modo y el tamaño físico van sin girar; ancho y alto, como se ve la pantalla.
        ancho, alto = modo["width"], modo["height"]
        if s.get("transform", "normal") in ("90", "270", "flipped-90", "flipped-270"):
            ancho, alto = alto, ancho
        fis = s.get("physical_size") or {}
        lista.append({"nombre": s["name"], "ancho": ancho, "alto": alto,
                      "modo": (modo["width"], modo["height"]),
                      "mm": (fis.get("width", 0), fis.get("height", 0)), "escala": s.get("scale", 1.0)})
    return lista


def aplicar(nombres=None):
    """Ajusta la escala de las pantallas (todas, o solo las de `nombres`)."""
    fija = preferencia()
    for s in salidas():
        if nombres is not None and s["nombre"] not in nombres:
            continue
        if fija is not None:
            # También con el tope de alto útil: una escala pensada para un monitor no deja
            # inservible otro más pequeño que se conecte después.
            quiere = max(1.0, min(fija, math.floor(s["alto"] / ALTO_MINIMO * 4) / 4))
        else:
            (ancho, alto), (ancho_mm, alto_mm) = s["modo"], s["mm"]
            quiere = escala_auto(ancho, alto, ancho_mm, alto_mm, s["nombre"])
        if abs(quiere - s["escala"]) > 0.01:
            subprocess.run(["wlr-randr", "--output", s["nombre"], "--scale", f"{quiere:g}"], check=False)


def huella(lista):
    return {s["nombre"]: (s["ancho"], s["alto"]) for s in lista}


def vigilar():
    """Al conectar una pantalla, le pone la escala; al conectarla o cambiar su modo, vuelve a poner
    el fondo. La escala de las que ya estaban no se toca: un cambio a mano (wdisplays) se respeta.
    Termina cuando el compositor se cierra."""
    antes = huella(salidas())
    fallos = 0
    while True:
        time.sleep(VIGILAR_CADA)
        try:
            ahora = huella(salidas())
            fallos = 0
        except (ConnectionError, ValueError, subprocess.TimeoutExpired):
            fallos += 1
            if fallos >= 3:
                return
            continue
        # Escala solo para las nuevas: si una que ya estaba cambia de modo, ha sido a mano (wdisplays)
        # y la escala elegida con ese cambio se respeta. El fondo, para las dos.
        nuevas = set(ahora) - set(antes)
        cambiadas = {n for n, modo in ahora.items() if antes.get(n) != modo}
        if nuevas:
            aplicar(nuevas)
        if cambiadas:
            if os.environ.get("COMMAND_OS_FONDO") == "1":
                subprocess.run(["command-os-wallpaper"], check=False)
        antes = ahora


# hyprlock mide los tamaños y las posiciones en píxeles físicos e ignora la escala de la pantalla:
# a escala 2 se vería a la mitad de tamaño. Se le da una copia de su configuración con esas medidas
# multiplicadas, un bloque por pantalla (cada una con su escala).
CLAVES_HYPRLOCK = ("font_size", "size", "position", "shadow_size", "outline_thickness", "border_size",
                   "rounding")
BLOQUES_HYPRLOCK = ("background", "image", "label", "input-field", "shape")
NUMERO = re.compile(r"(?<![\w.%])(-?\d+(?:\.\d+)?)(?![\w.%])")


def escalar_valor(valor, escala):
    """«300, 44» -> «600, 88» a escala 2. Los porcentajes de la pantalla ya escalan solos."""
    partes = []
    for parte in valor.split(","):
        if "%" not in parte:
            parte = NUMERO.sub(lambda m: f"{round(float(m.group(1)) * escala):d}", parte)
        partes.append(parte)
    return ",".join(partes)


def hyprlock(ruta, escalas):
    """Configuración de hyprlock con las medidas de cada widget escaladas por pantalla."""
    with open(ruta, encoding="utf-8") as f:
        lineas = f.read().splitlines()
    if all(abs(e - 1) < 0.01 for e in escalas.values()):
        return "\n".join(lineas) + "\n"
    salida, bloque = [], None
    for linea in lineas:
        limpia = linea.strip()
        if bloque is None:
            m = re.match(r"([\w-]+)\s*\{$", limpia)
            if m and m.group(1) in BLOQUES_HYPRLOCK:
                bloque = [linea]
            else:
                salida.append(linea)
            continue
        bloque.append(linea)
        if limpia != "}":
            continue
        for nombre, escala in escalas.items():
            salida += [bloque[0], f"    monitor = {nombre}"]
            for b in bloque[1:]:
                clave, igual, valor = b.partition("=")
                if clave.strip() == "monitor":
                    continue
                if igual and clave.strip() in CLAVES_HYPRLOCK:
                    b = f"{clave}= {escalar_valor(valor.strip(), escala)}"
                salida.append(b)
        bloque = None
    return "\n".join(salida) + "\n"


def main(args):
    orden = args[0] if args else ""
    if orden == "escala" and len(args) in (5, 6):
        ancho, alto, ancho_mm, alto_mm = (int(x) for x in args[1:5])
        nombre = args[5] if len(args) == 6 else ""
        print(f"{escala_auto(ancho, alto, ancho_mm, alto_mm, nombre):g}")
    elif orden == "aplicar":
        aplicar()
    elif orden == "vigilar":
        vigilar()
    elif orden == "lista":
        for s in salidas():
            print(s["nombre"], s["ancho"], s["alto"], f"{s['escala']:g}")
    elif orden == "hyprlock" and len(args) == 2:
        sys.stdout.write(hyprlock(args[1], {s["nombre"]: s["escala"] for s in salidas()}))
    else:
        print((__doc__ or "").strip().split("\n\n")[0], file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main(sys.argv[1:]))
    except (ConnectionError, FileNotFoundError, subprocess.TimeoutExpired) as e:
        print(f"command-os-pantallas: sin acceso a las pantallas ({e})", file=sys.stderr)
        sys.exit(1)
