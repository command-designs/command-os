#!/usr/bin/env python3
"""Command OS — aplicaciones fijadas en la barra, a la izquierda de las ventanas abiertas.

Waybar no sabe fijar aplicaciones (wlr/taskbar solo enseña ventanas, y su clic derecho no puede lanzar
órdenes): cada aplicación fijada es un módulo custom/fijada#fN con su icono de fondo, dentro de
group/fijadas. Este programa escribe esa parte de la configuración (la incluye config.jsonc) y una hoja
de estilo que importa la de la barra y añade los iconos; al cambiar la lista, recarga Waybar (SIGUSR2).
docs/notas/escritorio.md § «Aplicaciones fijadas».

    fijadas.py generar [ESTILO]   escribe la configuración y la hoja de estilo; imprime la ruta de la hoja
    fijadas.py abrir ID           abre la aplicación (clic)
    fijadas.py menu ID            quitar, mover o fijar otra (clic derecho en una fijada)
    fijadas.py fijar              elige una aplicación del lanzador y la fija (clic derecho en el logo)
    fijadas.py anadir ID | quitar ID | mover ID -1|1   lo mismo sin preguntar

ID es el nombre del .desktop (firefox.desktop). La lista va en ~/.config/command-os/fijadas, una por
línea; sin el archivo, las de serie (navegador, archivos, terminal y tienda). No usa GTK: lo prueba
tests/barra.sh sin pantalla.
"""
import configparser
import json
import os
import re
import shlex
import subprocess
import sys

from traducir import traductor

CONFIG = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
LISTA = os.path.join(CONFIG, "command-os", "fijadas")
RUN = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "", "command-os", "barra")
DE_SERIE = ["firefox.desktop", "thunar.desktop", "kitty.desktop", "io.github.kolunmi.Bazaar.desktop"]
TEMAS = ["Papirus-Dark", "Papirus", "hicolor"]
# Primero los SVG (se ven nítidos a cualquier escala), luego PNG grandes que GTK reduce.
TAMANOS_SVG = ["scalable", "16x16", "22x22", "24x24", "32x32", "48x48", "64x64"]
TAMANOS_PNG = ["48x48", "64x64", "32x32", "128x128", "256x256", "24x24", "22x22", "16x16"]
ID = re.compile(r"^[A-Za-z0-9._+-]+\.desktop$")
TAG = "command-os-fijadas"


def datos():
    """Las carpetas de datos de XDG, la del usuario primero."""
    casa = os.environ.get("XDG_DATA_HOME") or os.path.expanduser("~/.local/share")
    sistema = os.environ.get("XDG_DATA_DIRS") or "/usr/local/share:/usr/share"
    return [casa] + [d for d in sistema.split(":") if d]


def ruta_desktop(ident):
    """El .desktop de un ID (las subcarpetas cuentan con «-»: kde-foo.desktop = kde/foo.desktop)."""
    if not ID.match(ident):
        return None
    for d in datos():
        base = os.path.join(d, "applications")
        candidatos = [os.path.join(base, ident)]
        partes = ident.split("-")
        for i in range(1, len(partes)):
            candidatos.append(os.path.join(base, "/".join(partes[:i]), "-".join(partes[i:])))
        for c in candidatos:
            if os.path.isfile(c):
                return c
    return None


def ident_de(ruta):
    """El ID de un .desktop dentro de una carpeta applications de XDG, o None. Sin seguir enlaces: los
    de Flatpak (exports/share/applications) apuntan fuera de la carpeta."""
    ruta = os.path.abspath(ruta)
    for d in datos():
        for base in {os.path.abspath(os.path.join(d, "applications")), os.path.realpath(os.path.join(d, "applications"))}:
            base += os.sep
            if ruta.startswith(base):
                ident = ruta[len(base):].replace(os.sep, "-")
                return ident if ID.match(ident) else None
    return None


def leer_desktop(ruta):
    p = configparser.RawConfigParser(interpolation=None, strict=False)
    p.optionxform = str  # las claves distinguen mayúsculas (Name[es])
    try:
        p.read(ruta, encoding="utf-8")
        return dict(p["Desktop Entry"])
    except (configparser.Error, KeyError, UnicodeDecodeError, OSError):
        return {}


def nombre(entrada, ident):
    """Name en el idioma de la sesión (Name[es_ES], Name[es]) o el Name sin idioma."""
    idioma = (os.environ.get("LANG") or "").split(".")[0]
    for clave in (f"Name[{idioma}]", f"Name[{idioma.split('_')[0]}]", "Name"):
        if entrada.get(clave):
            return entrada[clave]
    return ident.removesuffix(".desktop")


def icono(nombre_icono):
    """Ruta del icono en el tema de Command OS (Papirus-Dark), sus padres o /usr/share/pixmaps."""
    if not nombre_icono:
        return None
    if os.path.isabs(nombre_icono):
        return nombre_icono if os.path.isfile(nombre_icono) else None
    bases = [os.path.join(d, "icons") for d in datos()] + [os.path.expanduser("~/.icons")]
    for tema in TEMAS:
        for ext, tamanos in (("svg", TAMANOS_SVG), ("png", TAMANOS_PNG)):
            for t in tamanos:
                for b in bases:
                    r = os.path.join(b, tema, t, "apps", f"{nombre_icono}.{ext}")
                    if os.path.isfile(r):
                        return r
    for d in datos():
        for ext in ("svg", "png", "xpm"):
            r = os.path.join(d, "pixmaps", f"{nombre_icono}.{ext}")
            if os.path.isfile(r):
                return r
    return None


def lista():
    """Los ID fijados, en orden, solo los que existen (una aplicación desinstalada desaparece sola)."""
    try:
        with open(LISTA, encoding="utf-8") as f:
            ids = [ln.strip() for ln in f if ln.strip()]
    except FileNotFoundError:
        ids = DE_SERIE
    except OSError:
        ids = []
    vistos = []
    for i in ids:
        if i not in vistos and ruta_desktop(i):
            vistos.append(i)
    return vistos


def guardar(ids):
    os.makedirs(os.path.dirname(LISTA), exist_ok=True)
    with open(LISTA + ".nuevo", "w", encoding="utf-8") as f:
        f.write("".join(f"{i}\n" for i in ids))
    os.replace(LISTA + ".nuevo", LISTA)


def pango(texto):
    # Waybar trata tooltip-format como marcado de Pango y {…} como sus campos.
    return (texto.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
            .replace("{", "").replace("}", ""))


def css_url(ruta):
    return 'url("file://' + ruta.replace("\\", "\\\\").replace('"', '\\"') + '")'


def generar(estilo=None, tr=None):
    """Escribe RUN/fijadas.jsonc (lo incluye config.jsonc) y RUN/estilo.css (la hoja de la barra más
    los iconos). Devuelve la ruta de la hoja. ESTILO es la hoja de la barra; sin él, la de la última vez."""
    _ = tr or traductor()
    # Solo en el XDG_RUNTIME_DIR de la cuenta (como command-os-config): nunca en /tmp, donde otra
    # cuenta podría dejar antes una configuración de Waybar con sus propias órdenes.
    run = os.environ.get("XDG_RUNTIME_DIR") or ""
    if not os.path.isabs(run) or not os.path.isdir(run) or os.stat(run).st_uid != os.getuid():
        raise RuntimeError("sin XDG_RUNTIME_DIR propio")
    os.makedirs(RUN, mode=0o700, exist_ok=True)
    base_guardada = os.path.join(RUN, "estilo-base")
    if estilo:
        with open(base_guardada, "w", encoding="utf-8") as f:
            f.write(estilo)
    else:
        try:
            with open(base_guardada, encoding="utf-8") as f:
                estilo = f.read().strip()
        except OSError:
            estilo = ruta_config("waybar/style.css")
    modulos, config = [], {}
    reglas = [f"@import {css_url(os.path.abspath(estilo))};"]
    for n, ident in enumerate(lista()):
        entrada = leer_desktop(ruta_desktop(ident))
        clave = f"custom/fijada#f{n}"
        modulos.append(clave)
        config[clave] = {
            "format": " ",
            "tooltip-format": pango(_("{app} · clic derecho: opciones").format(app=nombre(entrada, ident))),
            "on-click": f"command-os-fijadas abrir {ident}",
            "on-click-right": f"command-os-fijadas menu {ident}",
        }
        ruta = icono(entrada.get("Icon", "")) or icono("application-x-executable")
        if ruta:
            reglas.append(f"#custom-fijada.f{n} {{ background-image: {css_url(ruta)}; }}")
    config["group/fijadas"] = {"orientation": "horizontal", "modules": modulos}
    escribir(os.path.join(RUN, "fijadas.jsonc"), json.dumps(config, ensure_ascii=False, indent=2) + "\n")
    hoja = os.path.join(RUN, "estilo.css")
    escribir(hoja, "\n".join(reglas) + "\n")
    return hoja


def escribir(ruta, texto):
    with open(ruta + ".nuevo", "w", encoding="utf-8") as f:
        f.write(texto)
    os.replace(ruta + ".nuevo", ruta)


def recargar():
    generar()
    subprocess.run(["pkill", "-USR2", "-u", str(os.getuid()), "-x", "waybar"], check=False)


def avisar(texto):
    subprocess.run(["notify-send", "--app-name", "command os", "--icon", "command-os", "--urgency", "low",
                    "--hint", f"string:x-canonical-private-synchronous:{TAG}", texto],
                   check=False, stderr=subprocess.DEVNULL)


def anadir(ident):
    ids = lista()
    if ident not in ids and ruta_desktop(ident):
        guardar(ids + [ident])
        recargar()
        return True
    return False


def quitar(ident):
    ids = lista()
    if ident in ids:
        guardar([i for i in ids if i != ident])
        recargar()


def mover(ident, paso):
    ids = lista()
    if ident not in ids:
        return
    i = ids.index(ident)
    j = max(0, min(len(ids) - 1, i + paso))
    if i != j:
        ids[i], ids[j] = ids[j], ids[i]
        guardar(ids)
        recargar()


def orden_terminal(entrada):
    """Para un .desktop con Terminal=true (btop), la orden en kitty: gio buscaría su propia lista de
    terminales (gnome-terminal, xterm…) y kitty no tiene por qué estar en ella. None si no es de terminal."""
    if entrada.get("Terminal", "").strip().lower() != "true":
        return None
    try:
        partes = shlex.split(entrada.get("Exec", ""))
    except ValueError:
        return None
    # Fuera los códigos de campo (%f, %U…): se abre sin archivos.
    partes = [p.replace("%%", "%") for p in partes if not re.fullmatch(r"%[A-Za-z]", p)]
    return ["kitty", "-e", *partes] if partes else None


def abrir(ident):
    ruta = ruta_desktop(ident)
    if not ruta:
        return
    # gio lanza el .desktop entero (Exec, DBusActivatable), como el lanzador; los de terminal, en kitty.
    orden = orden_terminal(leer_desktop(ruta)) or ["gio", "launch", ruta]
    subprocess.Popen(orden, start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def ruta_config(ruta):
    """La configuración del usuario o la de serie (command-os-config)."""
    r = subprocess.run(["command-os-config", ruta], capture_output=True, text=True, check=False)
    return r.stdout.strip()


def config_wofi(archivo):
    return ruta_config(f"wofi/{archivo}")


def menu(ident):
    """El menú del clic derecho, con el estilo del menú de energía."""
    _ = traductor()
    if subprocess.run(["pkill", "-x", "wofi"], check=False).returncode == 0:
        return  # el segundo clic lo cierra, como el lanzador
    ids = lista()
    opciones = [("quitar", "\U000F0404   " + _("quitar de la barra"))]
    if ident in ids and ids.index(ident) > 0:
        opciones.append(("izquierda", "\U000F004D   " + _("mover a la izquierda")))
    if ident in ids and ids.index(ident) < len(ids) - 1:
        opciones.append(("derecha", "\U000F0054   " + _("mover a la derecha")))
    opciones.append(("fijar", "\U000F0403   " + _("fijar otra aplicación")))
    r = subprocess.run(["wofi", "--dmenu", "--prompt", TAG, "--style", config_wofi("power.css"),
                        "--define", "hide_search=true", "--cache-file", "/dev/null",
                        "--width", "300", "--height", str(22 + 40 * len(opciones))],
                       input="\n".join(t for _c, t in opciones) + "\n", capture_output=True, text=True, check=False)
    elegida = next((c for c, t in opciones if t == r.stdout.strip()), None)
    if elegida == "quitar":
        quitar(ident)
    elif elegida == "izquierda":
        mover(ident, -1)
    elif elegida == "derecha":
        mover(ident, 1)
    elif elegida == "fijar":
        fijar()


def fijar():
    """El lanzador de siempre, pero en vez de abrir la aplicación elegida, la fija."""
    _ = traductor()
    if subprocess.run(["pkill", "-x", "wofi"], check=False).returncode == 0:
        return
    r = subprocess.run(["wofi", "--conf", config_wofi("config"), "--style", config_wofi("style.css"),
                        "--prompt", _("fijar en la barra"), "--show", "drun",
                        "--define", "drun-print_desktop_file=true"],
                       capture_output=True, text=True, check=False)
    # Imprime la ruta del .desktop (y, si se eligió una acción, su nombre detrás).
    m = re.match(r"(.+?\.desktop)\b", r.stdout.strip())
    if not m:
        return
    ident = ident_de(m.group(1))
    if ident is None:
        return
    if anadir(ident):
        avisar(_("{app} fijada en la barra").format(app=nombre(leer_desktop(ruta_desktop(ident)), ident)))
    else:
        avisar(_("ya estaba en la barra"))


def main(args):
    orden, resto = (args[0], args[1:]) if args else ("", [])
    if orden == "generar":
        print(generar(resto[0] if resto else None))
    elif orden == "abrir" and len(resto) == 1:
        abrir(resto[0])
    elif orden == "menu" and len(resto) == 1:
        menu(resto[0])
    elif orden == "fijar" and not resto:
        fijar()
    elif orden == "anadir" and len(resto) == 1:
        return 0 if anadir(resto[0]) else 1
    elif orden == "quitar" and len(resto) == 1:
        quitar(resto[0])
    elif orden == "mover" and len(resto) == 2 and resto[1] in ("-1", "1"):
        mover(resto[0], int(resto[1]))
    else:
        print((__doc__ or "").strip().split("\n\n")[2], file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
