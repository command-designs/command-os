"""Genera las piezas del tema de GRUB de Command OS (os/branding/grub/, docs/DISENO.md).

GRUB dibuja los recuadros con nueve piezas (esquinas, lados y centro) que estira a lo que haga falta:
- panel_*: el panel del menú, como el de la pantalla de inicio de sesión (Graphite con borde Steel
  de 1 px, marca v2).
- sel_*: la entrada elegida, en Slate con la barra Signal Red a la izquierda (como el lanzador).
- thumb_c: la barra de desplazamiento (submenús largos, p. ej. las instantáneas).
- logo-<ancho>.png: el wordmark de 200 a 600 px de ancho, cada 20 (GRUB no escala las imágenes del
  tema; lib/apply-boot elige el que toca para la pantalla).
El fondo (void) se copia al instalar desde /usr/share/command-os; las fuentes y theme.txt los genera
lib/apply-boot a la medida de la pantalla.
Uso: python build/make-grub-theme.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent / "os" / "branding"
OUT = ROOT / "grub"
WORD = Image.open(ROOT / "logo" / "command-wordmark-white.png").convert("RGBA")
GRAPHITE = (21, 21, 21, 255)
SLATE = (31, 31, 31, 255)
STEEL = (42, 42, 42, 255)
SMOKE = (133, 130, 124, 255)
SIGNAL_RED = (165, 21, 0, 255)


def px(name, size, color):
    Image.new("RGBA", size, color).save(OUT / f"{name}.png", optimize=True)


OUT.mkdir(parents=True, exist_ok=True)
# Panel: borde de 1 px en los cuatro lados.
for n in ("nw", "n", "ne", "w", "e", "sw", "s", "se"):
    px(f"panel_{n}", (1, 1), STEEL)
px("panel_c", (1, 1), GRAPHITE)
# Entrada elegida: barra Signal Red de 4 px a la izquierda y fondo Slate.
px("sel_w", (4, 1), SIGNAL_RED)
px("sel_c", (1, 1), SLATE)
px("thumb_c", (1, 1), SMOKE)
for w in range(200, 601, 20):
    h = round(WORD.height * w / WORD.width)
    WORD.resize((w, h), Image.Resampling.LANCZOS).save(OUT / f"logo-{w}.png", optimize=True)
print("piezas en", OUT)
