"""Genera las piezas del tema de GRUB de Command OS (os/branding/grub/, docs/DISENO.md).

GRUB dibuja los recuadros con nueve piezas (esquinas, lados y centro) que estira a lo que haga falta:
- panel_*: el panel del menú, como el de la pantalla de inicio de sesión: Graphite con filo Steel de
  1 px y el chaflán de .panel (marca v2).
- sel_*: la entrada elegida, en Slate con la barra Red Hot a la izquierda (la paleta de lenguaje.html).
- thumb_c: la barra de desplazamiento (submenús largos, p. ej. las instantáneas).
- logo-<ancho>.png: el wordmark de 200 a 600 px de ancho, cada 20 (GRUB no escala las imágenes del
  tema; lib/apply-boot elige el que toca para la pantalla).
El fondo (void) se copia al instalar desde /usr/share/command-os; las fuentes y theme.txt los genera
lib/apply-boot a la medida de la pantalla.
Uso: python build/make-grub-theme.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent / "os" / "branding"
OUT = ROOT / "grub"
WORD = Image.open(ROOT / "logo" / "command-wordmark-white.png").convert("RGBA")
GRAPHITE = (21, 21, 21, 255)
SLATE = (31, 31, 31, 255)
STEEL = (42, 42, 42, 255)
SMOKE = (133, 130, 124, 255)
RED_HOT = (245, 72, 44, 255)


def px(name, size, color):
    Image.new("RGBA", size, color).save(OUT / f"{name}.png", optimize=True)


OUT.mkdir(parents=True, exist_ok=True)


def esquina_cortada(c):
    """Esquina de arriba a la izquierda de c x c con el chaflán de .panel: filo Steel de 1 px en la
    diagonal (también 1 px de grueso: el corte de dentro va √2 más adentro, como build/make-chaflanes.py)
    y Graphite por dentro. Con supermuestreo: Pillow no suaviza los polígonos."""
    ss = 8
    img = Image.new("RGBA", (c * ss, c * ss), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(c * ss, 0), (c * ss, c * ss), (0, c * ss)], fill=STEEL)
    k = (c + 2 ** 0.5) * ss
    d.polygon([(c * ss, k - c * ss), (c * ss, c * ss), (k - c * ss, c * ss)], fill=GRAPHITE)
    return img.resize((c, c), Image.Resampling.LANCZOS)


# Panel con el chaflán de .panel (BRAND § 6: --cut-md, 14 px, arriba a la izquierda y abajo a la
# derecha). Todas las piezas tienen el grueso del corte (GRUB pone el borde con el tamaño de las
# piezas): filo Steel de 1 px por fuera y Graphite por dentro, que sigue con el centro. lib/apply-boot
# cuenta con este grueso en el alto del menú: si cambia, cambiarlo también allí.
C = 14
nw = esquina_cortada(C)
nw.save(OUT / "panel_nw.png", optimize=True)
nw.rotate(180).save(OUT / "panel_se.png", optimize=True)
for nombre, filo in {"ne": ((0, 0, C - 1, 0), (C - 1, 0, C - 1, C - 1)),
                     "sw": ((0, 0, 0, C - 1), (0, C - 1, C - 1, C - 1))}.items():
    img = Image.new("RGBA", (C, C), GRAPHITE)
    for linea in filo:
        ImageDraw.Draw(img).line(linea, fill=STEEL)
    img.save(OUT / f"panel_{nombre}.png", optimize=True)
for nombre, tam, linea in (("n", (1, C), (0, 0, 0, 0)), ("s", (1, C), (0, C - 1, 0, C - 1)),
                           ("w", (C, 1), (0, 0, 0, 0)), ("e", (C, 1), (C - 1, 0, C - 1, 0))):
    img = Image.new("RGBA", tam, GRAPHITE)
    ImageDraw.Draw(img).line(linea, fill=STEEL)
    img.save(OUT / f"panel_{nombre}.png", optimize=True)
px("panel_c", (1, 1), GRAPHITE)
# Entrada elegida: barra Signal Red de 4 px a la izquierda y fondo Slate.
px("sel_w", (2, 1), RED_HOT)
px("sel_c", (1, 1), SLATE)
px("thumb_c", (1, 1), SMOKE)
for w in range(200, 601, 20):
    h = round(WORD.height * w / WORD.width)
    WORD.resize((w, h), Image.Resampling.LANCZOS).save(OUT / f"logo-{w}.png", optimize=True)
print("piezas en", OUT)
