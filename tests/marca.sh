#!/usr/bin/env bash
# Command OS — prueba de la marca (docs/DISENO.md): ningún archivo del sistema ni generador de build/
# usa un color fuera de la paleta v2 de Command (tokens.css de command-web), salvo los colores extra
# permitidos de la lista de abajo, ni nada del estilo anterior (sus colores, también sin «#», y sus
# palabras), y los halos solo están en la señal (BRAND 2.1 § 7.2; nunca en texto, paneles ni bordes). La
# forma: los chaflanes generados al día y citados bien, y solo los radios de la marca. El splash:
# sus imágenes completas y la lista de comprobaciones igual en el servicio, el gancho y el tema.
# El movimiento: solo las curvas de la marca y ninguna animación en bucle (BRAND § 9).
# Mira colores hex (#rrggbb y #rrggbbaa, y rgba(rrggbbaa) de Hyprland), rgb()/rgba(), tuplas RGB de
# Python, secuencias de color de terminal (38;2;r;g;b) y los colores de Plymouth (0.93, 0.92, 0.90).
# Corre en cualquier Linux con python3 (GitHub Actions, ver .github/workflows/pruebas.yml). Sale con 1
# si algo falla.
set -uo pipefail

RAIZ=$(cd "$(dirname "$0")/.." && pwd)
cd "${RAIZ}" || exit 1

echo "==> Colores fuera de la paleta v2 y restos del estilo anterior"
python3 - <<'PY'
import re
import subprocess
import sys

# Copia de la paleta de tokens.css v2.0 (command-web) y de los colores HUD de BRAND.md 2.1 § 7. Si
# la marca cambia, se cambia aquí y en todos los archivos de tema a la vez. El negro solo sale en
# sombras (como en tokens.css). --holo y --holo-dim son Bone translúcido y --glow, Red Hot.
PALETA = {
    "1a1a1a": "Carbon", "0e0e0e": "Void", "151515": "Graphite", "1f1f1f": "Slate",
    "2a2a2a": "Steel", "3a3a3a": "Iron", "ffffff": "White", "edebe6": "Bone", "a3a09a": "Ash",
    "85827c": "Smoke", "a51500": "Signal Red", "f5482c": "Red Hot", "6e0e00": "Red Deep",
    "3ddc84": "OK", "ffb020": "Warn", "6e6c68": "Idle", "000000": "negro (sombras)",
    "b81a02": "hover del botón principal (2.1)", "1a1311": "fondo de lo seleccionado (2.1)",
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

# El estilo anterior (Cyberpunk, cambiado por la marca v2 el 2026-10-19; docs/decisiones/README.md).
# Sus colores se buscan también sin «#» (swaylock los lleva así) y sus palabras no pueden volver.
# «HUD» ya no es una de ellas: desde BRAND 2.1 es el nombre del lenguaje de la marca.
VIEJOS = {"d13449", "5bbfc4", "e2c044", "0d0b0e", "15121a", "2e2630", "e8607a", "1d1820", "6f6870",
          "a8a2a6", "a8283a", "2f8a8f", "d9b441", "d6d2d4", "8ad6da"}
PALABRAS = re.compile(r"\b(cyberpunk|2077|glitch|cian)\b", re.IGNORECASE)
# Palabras permitidas por archivo, con el motivo.
PALABRAS_EXTRA = {
    "os/dotfiles/kitty/kitty.conf": {"cian"},  # el color 6 de ANSI se llama así (EXTRA, arriba)
}

BINARIOS = (".png", ".jpg", ".jpeg", ".wav", ".ttf", ".otf", ".pf2", ".gz", ".zst", ".mo", ".po", ".pot")
archivos = [f for f in subprocess.run(["git", "ls-files", "os", "build"], capture_output=True,
                                      text=True, check=True).stdout.splitlines()
            if not f.lower().endswith(BINARIOS)]

HEX = re.compile(r"#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?(?![0-9a-zA-Z_-])")
RGB = re.compile(r"rgba?\(\s*(\d{1,3})[\s,]+(\d{1,3})[\s,]+(\d{1,3})")
HYPR = re.compile(r"rgba?\(\s*([0-9a-fA-F]{6})([0-9a-fA-F]{2})?\s*\)")  # Hyprland: rgba(f5482cff)
TUPLA = re.compile(r"\(\s*(\d{1,3})\s*,\s*(\d{1,3})\s*,\s*(\d{1,3})\s*(?:,\s*\d{1,3}\s*)?\)")
ANSI = re.compile(r"[34]8;2;(\d{1,3});(\d{1,3});(\d{1,3})m")
FLOTANTES = re.compile(r"(?<![\d.])([01]\.\d+)\s*,\s*([01]\.\d+)\s*,\s*([01]\.\d+)")


def colores(ruta, texto):
    """(línea, hex) de cada color que aparece en el texto."""
    for n, linea in enumerate(texto.splitlines(), 1):
        for m in HEX.finditer(linea):
            yield n, m.group(1).lower()
        for m in HYPR.finditer(linea):
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
    for n, h in fuera:
        print(f"  MAL  {ruta}:{n}: #{h} no es de la paleta v2")
        fallos += 1
    for n, linea in enumerate(texto.splitlines(), 1):
        for h in VIEJOS:
            if re.search(r"(?<![0-9a-zA-Z])" + h + r"(?![0-9a-zA-Z])", linea, re.IGNORECASE):
                print(f"  MAL  {ruta}:{n}: {h} es un color del estilo anterior")
                fallos += 1
        for m in PALABRAS.finditer(linea):
            if m.group(1).lower() not in PALABRAS_EXTRA.get(ruta, set()):
                print(f"  MAL  {ruta}:{n}: «{m.group(1)}» es del estilo anterior")
                fallos += 1
for ruta in set(EXTRA) | set(PALABRAS_EXTRA):
    if ruta not in archivos:
        print(f"  MAL  {ruta}: tiene colores o palabras extra permitidos pero ya no existe")
        fallos += 1
if not fallos:
    print(f"  ok   {len(archivos)} archivos con los colores de la paleta v2 (y los extra permitidos), sin restos del estilo anterior")
sys.exit(1 if fallos else 0)
PY
colores=$?

echo "==> Halos solo en la señal (BRAND 2.1 § 7.2: barra del logo, plano, firma y LED)"
# Nunca en el texto: ni text-shadow ni las sombras de hyprlock (que se aplican a sus textos).
brillos=$(grep -n -E 'text-shadow:[[:space:]]*[^[:space:]n;]|^\s*shadow_(size|passes|color)\s*=' \
  os/dotfiles/waybar/*.css os/dotfiles/wofi/*.css os/dotfiles/gtk-*/gtk.css os/dotfiles/swaync/*.css \
  os/branding/greeter/command.css os/dotfiles/hypr/*.conf 2>/dev/null)
# Ni en paneles ni en bordes: en las hojas, una sombra de color con desenfoque (un halo; las negras
# son sombras de flotantes) solo puede ir en un LED de estado (un selector con «led»).
brillos+=$(python3 - <<'PY'
import glob
import re

HALO = re.compile(r"box-shadow:([^;]*)")
DESENFOQUE = re.compile(r"^\s*(?:inset\s+)?-?[\d.]+\w*\s+-?[\d.]+\w*\s+[1-9][\d.]*\w*")
NEGRO = re.compile(r"rgba?\(\s*0[\s,]+0[\s,]+0\b|#000(?:000)?\b|\bblack\b")
for ruta in sorted(glob.glob("os/dotfiles/**/*.css", recursive=True) + ["os/branding/greeter/command.css"]):
    texto = re.sub(r"/\*.*?\*/", lambda m: "\n" * m.group().count("\n"), open(ruta, encoding="utf-8").read(), flags=re.S)
    for bloque in re.finditer(r"([^{}]+)\{([^{}]*)\}", texto):
        selector, cuerpo = bloque.group(1).strip(), bloque.group(2)
        for m in HALO.finditer(cuerpo):
            # Una capa por coma de primer nivel (las de rgba() no separan capas).
            capas = [c for c in re.split(r",(?![^()]*\))", m.group(1)) if DESENFOQUE.search(c) and not NEGRO.search(c)]
            if capas and "led" not in selector.lower():
                n = texto.count("\n", 0, bloque.start(2) + m.start()) + 1
                print(f"\n{ruta}:{n}: halo fuera de un LED ({selector.splitlines()[-1].strip()})")
PY
)
if [[ -z "${brillos}" ]]; then
  echo "  ok   sin halos en el texto, los paneles ni los bordes (barra, lanzador, GTK, avisos, inicio y bloqueo)"
else
  echo "  MAL  halos fuera de la señal:"; echo "${brillos}" | sed '/^$/d; s/^/         /'
fi

echo "==> Forma (chaflanes, escuadras y radios; BRAND § 6)"
forma=0
# Los SVG de los chaflanes son los que dibuja su generador.
python3 build/make-chaflanes.py --comprobar || forma=1
# Cada chaflán que cita una hoja existe (las hojas GTK los buscan en chaflanes/, junto a ellas).
for nombre in $(grep -rhoE 'chaflanes/[a-z-]+\.svg' os/dotfiles os/branding/greeter | sort -u); do
  if [[ ! -f "os/branding/${nombre}" ]]; then echo "  MAL  una hoja cita ${nombre}, que no existe"; forma=1; fi
done
# Los botones de la barra de título son los de su generador, y los que citan las hojas GTK (en
# botones/, una copia de los de labwc) existen: una sola barra de título para todas las ventanas.
python3 build/make-labwc-buttons.py --comprobar || forma=1
for nombre in $(grep -rhoE 'botones/[a-z_-]+\.svg' os/dotfiles | sort -u); do
  if [[ ! -f "os/branding/labwc/Command/labwc/${nombre#botones/}" ]]; then
    echo "  MAL  una hoja cita ${nombre}, que no existe"; forma=1
  fi
done
# Radios: 0 (esquinas vivas), 2 px en los campos de texto y redondos los radios y deslizadores.
radios=$(grep -rnE 'border-radius:\s*[^;]+' os/dotfiles os/branding/greeter --include='*.css' \
  | grep -vE 'border-radius:\s*(0|0px|2px|9999px)\s*(!important)?\s*;')
if [[ -n "${radios}" ]]; then echo "  MAL  radios fuera de la marca:"; echo "${radios}" | sed 's/^/         /'; forma=1; fi
# wofi 1.5 con hide_search deja ver solo la primera opción: los paneles ocultan el buscador en su hoja.
if grep -rn 'hide_search' os/bin os/lib >/dev/null; then
  echo "  MAL  hide_search en un panel de wofi (enseña una sola opción):"
  grep -rn 'hide_search' os/bin os/lib | sed 's/^/         /'; forma=1
fi
(( forma == 0 )) && echo "  ok   chaflanes y botones al día y citados bien, radios de la marca, paneles de wofi sin hide_search"

echo "==> Splash (firma corta y comprobaciones de arranque; BRAND § 9)"
splash=0
dir=os/branding/plymouth/command
script="${dir}/command.script"
# Los fotogramas del símbolo que carga command.script existen todos (y no sobra ninguno).
frames=$(sed -nE 's/^SIM_FRAMES = ([0-9]+);.*/\1/p' "${script}")
hay=$(find "${dir}" -name 'simbolo-*.png' | wc -l)
if [[ -z "${frames}" || "${hay}" -ne "${frames}" || ! -f "${dir}/simbolo-$((frames - 1)).png" ]]; then
  echo "  MAL  command.script carga ${frames:-?} fotogramas del símbolo y hay ${hay} (python build/make-plymouth.py)"; splash=1
fi
# Las comprobaciones de lib/diagnostico-arranque son tantas como filas pinta el tema y como
# nombres (diag-N) y números (diag-ix-N) hay; el gancho del initramfs manda un estado por fila.
filas=$(sed -nE 's/^ROWS = ([0-9]+);.*/\1/p' "${script}")
comprobaciones=$(sed -n '/^COMPROBACIONES=(/,/^)/p' os/lib/diagnostico-arranque | grep -cE '^  [^ #]')
gancho=$(grep -oE 'cmd-diag \$\{idioma\} [a-z]+' os/initcpio/hooks/command-os-cifrado | awk '{print length($3)}')
if [[ -z "${filas}" || "${comprobaciones}" -ne "${filas}" || "${gancho:-0}" -ne "${filas}" ]]; then
  echo "  MAL  comprobaciones: ${comprobaciones} en diagnostico-arranque, ${filas:-?} filas en command.script, ${gancho:-?} en el gancho"; splash=1
fi
for ((n = 1; n <= ${filas:-0}; n++)); do
  for img in "diag-${n}.es.png" "diag-ix-${n}.png"; do
    [[ -f "${dir}/${img}" ]] || { echo "  MAL  falta ${img} (python build/make-plymouth-textos.py)"; splash=1; }
  done
done
for ((n = 0; n <= ${filas:-0}; n++)); do
  for img in "diag-cuenta-${n}.png" "linea-${n}.es.png" "linea-${n}.en.png"; do
    [[ -f "${dir}/${img}" ]] || { echo "  MAL  falta ${img} (python build/make-plymouth-textos.py)"; splash=1; }
  done
done
# Pantalla de carga (lenguaje.html § 04): los consejos que sortea el tema y las piezas fijas.
consejos=$(sed -nE 's/^CONSEJOS = ([0-9]+);.*/\1/p' "${script}")
[[ -n "${consejos}" ]] || { echo "  MAL  command.script no dice cuántos consejos hay (CONSEJOS)"; splash=1; }
for ((n = 1; n <= ${consejos:-0}; n++)); do
  for img in "consejo-${n}.es.png" "consejo-${n}.en.png"; do
    [[ -f "${dir}/${img}" ]] || { echo "  MAL  falta ${img} (python build/make-plymouth-textos.py)"; splash=1; }
  done
done
if compgen -G "${dir}/consejo-$(( ${consejos:-0} + 1 )).*.png" >/dev/null; then
  echo "  MAL  sobra consejo-$(( consejos + 1 )): CONSEJOS en command.script no los cuenta todos"; splash=1
fi
for img in anillo.png punto.png puntos.png wordmark-mini.png codigo.png; do
  [[ -f "${dir}/${img}" ]] || { echo "  MAL  falta ${img} (python build/make-plymouth.py o make-plymouth-textos.py)"; splash=1; }
done
# Nada del splash anterior: ni fotogramas viejos ni lectura de los mensajes de systemd como consola.
if compgen -G "${dir}/frame-*.png" >/dev/null || grep -qE 'push_line|log_sprite' "${script}"; then
  echo "  MAL  quedan restos de la consola de servicios del splash anterior"; splash=1
fi
(( splash == 0 )) && echo "  ok   ${frames} fotogramas del símbolo, ${filas} comprobaciones iguales en el servicio, el gancho y el tema"

echo
echo "==> Movimiento (BRAND § 9)"
movimiento=0
# En las hojas, solo las curvas de la marca (--ease-out, --ease-in-out y --ease-snap), ni las de otros
# sistemas (Material: 0.4, 0, 0.2, 1) ni las palabras de CSS (ease, linear…), que no son de la marca.
hojas=(os/dotfiles os/branding/greeter)
curvas=$(grep -rnoE 'cubic-bezier\([^)]*\)' "${hojas[@]}" --include='*.css' \
  | grep -vE 'cubic-bezier\((0\.16, 1, 0\.3, 1|0\.65, 0, 0\.35, 1|0\.2, 0\.9, 0\.1, 1\.25)\)$')
palabras=$(grep -rnE '(transition|animation)(-timing-function)?:[^;]*\b(ease|ease-in|ease-out|ease-in-out|linear)\b' \
  "${hojas[@]}" --include='*.css')
if [[ -n "${curvas}${palabras}" ]]; then
  echo "  MAL  curvas fuera de la marca:"; printf '%s\n%s\n' "${curvas}" "${palabras}" | sed '/^$/d; s/^/         /'
  movimiento=1
fi
# Hyprland (hyprland.lua): sus curvas, también las de la marca, y sin halos (glow) en las ventanas.
curvas=$(grep -rnoE 'points = \{ \{ [0-9.]+, [0-9.]+ \}, \{ [0-9.]+, [0-9.]+ \} \}' os/dotfiles --include='*.lua' \
  | grep -vE 'points = \{ \{ (0\.16, 1 \}, \{ 0\.3, 1|0\.65, 0 \}, \{ 0\.35, 1|0\.2, 0\.9 \}, \{ 0\.1, 1\.25) \} \}$')
otras=$(grep -rnE 'hl\.curve\(' os/dotfiles --include='*.lua' | grep -v 'type = "bezier", points = ')
halos=$(grep -rnE 'glow = \{[^}]*enabled = true' os/dotfiles --include='*.lua')
if [[ -n "${curvas}${otras}${halos}" ]]; then
  echo "  MAL  hyprland: curvas fuera de la marca o halos:"
  printf '%s\n%s\n%s\n' "${curvas}" "${otras}" "${halos}" | sed '/^$/d; s/^/         /'
  movimiento=1
fi
# Nada se mueve en reposo (AGENTS.md § «Ligereza»): ninguna animación en bucle.
bucles=$(grep -rnE 'infinite' "${hojas[@]}" --include='*.css')
if [[ -n "${bucles}" ]]; then echo "  MAL  animaciones en bucle:"; echo "${bucles}" | sed 's/^/         /'; movimiento=1; fi
(( movimiento == 0 )) && echo "  ok   solo las curvas de la marca y ninguna animación en bucle"

echo
if (( colores != 0 )) || [[ -n "${brillos}" ]] || (( forma != 0 )) || (( splash != 0 )) || (( movimiento != 0 )); then
  echo "==> Hay fallos"; exit 1
fi
echo "==> Todo correcto"
