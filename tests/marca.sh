#!/usr/bin/env bash
# Command OS — prueba de la marca (docs/DISENO.md): ningún archivo del sistema ni generador de build/
# usa un color fuera de la paleta v2 de Command (tokens.css de command-web), salvo los colores extra
# permitidos de la lista de abajo, y nada lleva brillos (el halo es solo de la barra del logo). La
# forma: los chaflanes generados al día y citados bien, y solo los radios de la marca.
# Mira colores hex (#rrggbb y #rrggbbaa), rgb()/rgba(), tuplas RGB de Python, secuencias de color
# de terminal (38;2;r;g;b) y los colores de Plymouth (0.93, 0.92, 0.90). Corre en cualquier Linux con
# python3 (GitHub Actions, ver .github/workflows/pruebas.yml). Sale con 1 si algo falla.
set -uo pipefail

RAIZ=$(cd "$(dirname "$0")/.." && pwd)
cd "${RAIZ}" || exit 1

echo "==> Colores fuera de la paleta v2"
python3 - <<'PY'
import re
import subprocess
import sys

# Copia de la paleta de tokens.css v2.0 (command-web). Si la marca cambia, se cambia aquí y en
# todos los archivos de tema a la vez. El negro solo sale en sombras (como en tokens.css).
PALETA = {
    "1a1a1a": "Carbon", "0e0e0e": "Void", "151515": "Graphite", "1f1f1f": "Slate",
    "2a2a2a": "Steel", "3a3a3a": "Iron", "ffffff": "White", "edebe6": "Bone", "a3a09a": "Ash",
    "85827c": "Smoke", "a51500": "Signal Red", "f5482c": "Red Hot", "6e0e00": "Red Deep",
    "3ddc84": "OK", "ffb020": "Warn", "6e6c68": "Idle", "000000": "negro (sombras)",
}

# Colores extra: solo donde hacen falta y en el archivo que los necesita (docs/DISENO.md).
EXTRA = {
    "os/dotfiles/kitty/kitty.conf": {
        # Los programas de terminal usan los 16 colores ANSI con significado (ls, git diff) y la
        # marca no tiene azul, magenta ni cian: van apagados para no competir con el rojo.
        "7d8fa8": "azul ANSI", "9fadc2": "azul claro ANSI",
        "a88ca0": "magenta ANSI", "c2aabb": "magenta claro ANSI",
        "84a3a0": "cian ANSI", "a6c0bd": "cian claro ANSI",
    },
}

# Exclusiones temporales: generadores que se rehacen enteros en un punto del ROADMAP. Cada punto
# quita su línea al terminar; si un archivo de aquí ya no tiene colores fuera de la paleta, la
# prueba falla para que se quite.
TEMPORALES = {
    "build/make-plymouth.py": "punto «Marca v2 — arranque» del ROADMAP",
}

BINARIOS = (".png", ".jpg", ".jpeg", ".wav", ".ttf", ".otf", ".pf2", ".gz", ".zst", ".mo", ".po", ".pot")
archivos = [f for f in subprocess.run(["git", "ls-files", "os", "build"], capture_output=True,
                                      text=True, check=True).stdout.splitlines()
            if not f.lower().endswith(BINARIOS)]

HEX = re.compile(r"#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?(?![0-9a-zA-Z_-])")
RGB = re.compile(r"rgba?\(\s*(\d{1,3})[\s,]+(\d{1,3})[\s,]+(\d{1,3})")
TUPLA = re.compile(r"\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(?:,\s*\d{1,3}\s*)?\)")
ANSI = re.compile(r"[34]8;2;(\d{1,3});(\d{1,3});(\d{1,3})m")
FLOTANTES = re.compile(r"(?<![\d.])([01]\.\d+)\s*,\s*([01]\.\d+)\s*,\s*([01]\.\d+)")


def colores(ruta, texto):
    """(línea, hex) de cada color que aparece en el texto."""
    for n, linea in enumerate(texto.splitlines(), 1):
        for m in HEX.finditer(linea):
            yield n, m.group(1).lower()
        triples = list(RGB.finditer(linea)) + list(ANSI.finditer(linea))
        if ruta.endswith(".py"):
            triples += TUPLA.finditer(linea)
        for m in triples:
            rgb = [int(x) for x in m.groups()[:3]]
            if max(rgb) <= 255:
                yield n, "%02x%02x%02x" % tuple(rgb)
        if ruta.endswith(".script"):
            for m in FLOTANTES.finditer(linea):
                yield n, "%02x%02x%02x" % tuple(round(float(x) * 255) for x in m.groups())


def cerca(h, permitidos):
    """Plymouth da los colores con dos decimales: se admite un redondeo de ±2 por canal."""
    r, g, b = (int(h[i:i + 2], 16) for i in (0, 2, 4))
    for p in permitidos:
        if max(abs(r - int(p[0:2], 16)), abs(g - int(p[2:4], 16)), abs(b - int(p[4:6], 16))) <= 2:
            return True
    return False


fallos = 0
for ruta in archivos:
    try:
        texto = open(ruta, encoding="utf-8").read()
    except (UnicodeDecodeError, FileNotFoundError, IsADirectoryError):
        continue
    permitidos = set(PALETA) | set(EXTRA.get(ruta, {}))
    fuera = [(n, h) for n, h in colores(ruta, texto)
             if h not in permitidos and not (ruta.endswith(".script") and cerca(h, permitidos))]
    if ruta in TEMPORALES:
        if not fuera:
            print(f"  MAL  {ruta}: ya no tiene colores fuera de la paleta; quítalo de TEMPORALES")
            fallos += 1
        else:
            print(f"  ok   {ruta}: excluido hasta el {TEMPORALES[ruta]}")
        continue
    for n, h in fuera:
        print(f"  MAL  {ruta}:{n}: #{h} no es de la paleta v2")
        fallos += 1
for ruta in EXTRA:
    if ruta not in archivos:
        print(f"  MAL  {ruta}: tiene colores extra permitidos pero ya no existe")
        fallos += 1
if not fallos:
    print(f"  ok   {len(archivos)} archivos con los colores de la paleta v2 (y los extra permitidos)")
sys.exit(1 if fallos else 0)
PY
colores=$?

echo "==> Sin brillos (el halo, solo en la barra del logo)"
brillos=$(grep -n -E 'text-shadow:\s*[^n;]|^\s*shadow_(size|passes|color)\s*=' \
  os/dotfiles/waybar/*.css os/dotfiles/wofi/*.css os/dotfiles/gtk-*/gtk.css \
  os/branding/greeter/command.css os/dotfiles/hypr/*.conf 2>/dev/null)
if [[ -z "${brillos}" ]]; then
  echo "  ok   ni text-shadow ni sombras de texto en la barra, el lanzador, GTK, el inicio y el bloqueo"
else
  echo "  MAL  brillos en el texto:"; echo "${brillos}" | sed 's/^/         /'
fi

echo "==> Forma (chaflanes, escuadras y radios; BRAND § 6)"
forma=0
# Los SVG de los chaflanes son los que dibuja su generador.
python3 build/make-chaflanes.py --comprobar || forma=1
# Cada chaflán que cita una hoja existe (las hojas GTK los buscan en chaflanes/, junto a ellas).
for nombre in $(grep -rhoE 'chaflanes/[a-z-]+\.svg' os/dotfiles os/branding/greeter | sort -u); do
  if [[ ! -f "os/branding/${nombre}" ]]; then echo "  MAL  una hoja cita ${nombre}, que no existe"; forma=1; fi
done
# Radios: 0 (esquinas vivas), 2 px en los campos de texto y redondos los radios y deslizadores.
radios=$(grep -rnE 'border-radius:\s*[^;]+' os/dotfiles os/branding/greeter --include='*.css' \
  | grep -vE 'border-radius:\s*(0|0px|2px|9999px)\s*;')
if [[ -n "${radios}" ]]; then echo "  MAL  radios fuera de la marca:"; echo "${radios}" | sed 's/^/         /'; forma=1; fi
# wofi 1.5 con hide_search deja ver solo la primera opción: los paneles ocultan el buscador en su hoja.
if grep -rn 'hide_search' os/bin os/lib >/dev/null; then
  echo "  MAL  hide_search en un panel de wofi (enseña una sola opción):"
  grep -rn 'hide_search' os/bin os/lib | sed 's/^/         /'; forma=1
fi
(( forma == 0 )) && echo "  ok   chaflanes al día y citados bien, radios de la marca, paneles de wofi sin hide_search"

echo
if (( colores != 0 )) || [[ -n "${brillos}" ]] || (( forma != 0 )); then echo "==> Hay fallos"; exit 1; fi
echo "==> Todo correcto"
