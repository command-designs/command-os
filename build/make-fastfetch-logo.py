"""Genera el logo de Command (la C con su barra) para fastfetch, en caracteres de medio bloque.

Cada carácter son dos «píxeles» (mitad de arriba y de abajo: ▀ ▄ █), así que con celdas de
terminal de proporción 1:2 el símbolo sale con su forma real. La C va en el color $1 y la barra en
$2; los colores (Bone y Signal Red, docs/DISENO.md) los pone ~/.config/fastfetch/config.jsonc.

Uso: python build/make-fastfetch-logo.py  ->  os/branding/fastfetch/command-logo.txt
"""
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent / "os" / "branding"
SRC = ROOT / "logo" / "command-mark-white.png"
OUT = ROOT / "fastfetch" / "command-logo.txt"
COLS = 26  # ancho en caracteres

img = Image.open(SRC).convert("RGBA")
rows_px = round(COLS * img.height / img.width)
rows_px += rows_px % 2  # par: dos píxeles por fila de texto
small = img.resize((COLS, rows_px), Image.Resampling.BOX)


def kind(x, y):
    r, g, _, a = small.getpixel((x, y))  # type: ignore[misc]
    if a < 128:
        return None
    return "c" if r > 200 and g > 200 else "b"  # blanco: la C; rojo: la barra


COLOR = {"c": "$1", "b": "$2"}
lines = []
for y in range(0, rows_px, 2):
    line, current = "", None
    for x in range(COLS):
        top, bottom = kind(x, y), kind(x, y + 1)
        if top is None and bottom is None:
            line += " "
            continue
        k = top or bottom or "c"
        if k != current:
            line += COLOR[k]
            current = k
        # Entre la C y la barra hay aire, así que nunca coinciden los dos colores en una celda.
        line += "█" if top and bottom else ("▀" if top else "▄")
    lines.append(line.rstrip())

OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text("\n".join(lines) + "\n", encoding="utf-8", newline="\n")
print(f"{len(lines)} líneas x {COLS} columnas -> {OUT}")
print("\n".join(l.replace("$1", "").replace("$2", "") for l in lines))
