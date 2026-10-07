"""Genera las piezas del tema de GRUB de Command OS (os/branding/grub/, docs/DISENO.md).

GRUB dibuja los recuadros con nueve piezas (esquinas, lados y centro) que estira a lo que haga falta:
- panel_*: el panel del menú, como el de la pantalla de inicio de sesión (fondo Void casi opaco,
  filo rojo de 3 px arriba y borde rojo tenue).
- sel_*: la entrada elegida, granate con una barra roja a la izquierda (como el campo activo).
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
VOID = (13, 11, 14, 240)
EDGE = (209, 52, 73, 150)
RED = (209, 52, 73, 255)
MAROON = (43, 17, 24, 255)


def px(name, size, color):
    Image.new("RGBA", size, color).save(OUT / f"{name}.png", optimize=True)


OUT.mkdir(parents=True, exist_ok=True)
# Panel: lados de 1 px, filo superior de 3 px.
for n in ("nw", "n", "ne"):
    px(f"panel_{n}", (1, 3), RED)
for n in ("w", "e", "sw", "s", "se"):
    px(f"panel_{n}", (1, 1), EDGE)
px("panel_c", (1, 1), VOID)
# Entrada elegida: barra roja de 4 px a la izquierda y fondo granate.
px("sel_w", (4, 1), RED)
px("sel_c", (1, 1), MAROON)
px("thumb_c", (1, 1), RED)
for w in range(200, 601, 20):
    h = round(WORD.height * w / WORD.width)
    WORD.resize((w, h), Image.Resampling.LANCZOS).save(OUT / f"logo-{w}.png", optimize=True)
print("piezas en", OUT)
