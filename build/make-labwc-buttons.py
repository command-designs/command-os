"""Genera los botones de la barra de título del tema de ventanas Command (labwc), docs/DISENO.md.

Glifos finos sobre fondo transparente, del tamaño exacto del botón (window.button.width/height de
themerc). Maximizar son las escuadras del fondo de pantalla; restaurar, dos marcos solapados.
Reposo: Ash (ventana activa) o Smoke (inactiva). Al pasar por encima: Bone sobre Steel y, para
cerrar, blanco sobre Signal Red (botón rojo con texto blanco, marca v2). labwc solo pinta su efecto
de hover genérico si falta el icono *_hover, así que los fondos de hover van dibujados en el SVG.

Uso: python build/make-labwc-buttons.py  ->  os/branding/labwc/Command/labwc/*.svg
"""
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / "os" / "branding" / "labwc" / "Command" / "labwc"
W, H = 30, 26          # = window.button.width / window.button.height en themerc
X0, Y0, S = 10, 8, 10  # caja del glifo: 10x10 px centrada
STROKE = 1.4

ASH, SMOKE = "#a3a09a", "#85827c"
STEEL, BONE = "#2a2a2a", "#edebe6"
SIGNAL_RED, WHITE = "#a51500", "#ffffff"


def path(d, color):
    return (f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{STROKE}" '
            'stroke-linecap="square" stroke-linejoin="miter"/>')


def glyph_close(c):
    return path(f"M{X0} {Y0}L{X0 + S} {Y0 + S}M{X0 + S} {Y0}L{X0} {Y0 + S}", c)


def glyph_iconify(c):
    return path(f"M{X0} {Y0 + S - 0.5}H{X0 + S}", c)


def glyph_max(c):
    a = 3.5  # brazo de cada escuadra
    x1, y1, x2, y2 = X0, Y0, X0 + S, Y0 + S
    return path(f"M{x1} {y1 + a}V{y1}H{x1 + a}M{x2 - a} {y1}H{x2}V{y1 + a}"
                f"M{x2} {y2 - a}V{y2}H{x2 - a}M{x1 + a} {y2}H{x1}V{y2 - a}", c)


def glyph_max_toggled(c):
    # Marco trasero (solo el borde que asoma) y marco delantero completo.
    back = f"M{X0 + 3} {Y0 + 2}V{Y0}H{X0 + S}V{Y0 + S - 3}H{X0 + S - 2}"
    front = f"M{X0} {Y0 + 3}H{X0 + S - 3}V{Y0 + S}H{X0}Z"
    return path(back, c) + path(front, c)


def svg(body, bg=None):
    rect = f'<rect width="{W}" height="{H}" fill="{bg}"/>' if bg else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
            f'viewBox="0 0 {W} {H}">{rect}{body}</svg>\n')


BUTTONS = {
    "close": glyph_close,
    "iconify": glyph_iconify,
    "max": glyph_max,
    "max_toggled": glyph_max_toggled,
}

OUT.mkdir(parents=True, exist_ok=True)
for name, glyph in BUTTONS.items():
    hover = (SIGNAL_RED, WHITE) if name == "close" else (STEEL, BONE)
    files = {
        f"{name}-active.svg": svg(glyph(ASH)),
        f"{name}-inactive.svg": svg(glyph(SMOKE)),
        f"{name}_hover-active.svg": svg(glyph(hover[1]), hover[0]),
        f"{name}_hover-inactive.svg": svg(glyph(hover[1]), hover[0]),
    }
    for fname, content in files.items():
        (OUT / fname).write_text(content, encoding="utf-8", newline="\n")
print(f"{len(BUTTONS) * 4} botones en {OUT}")
