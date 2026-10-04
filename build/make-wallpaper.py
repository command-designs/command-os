"""Genera el wallpaper de Command OS: HUD estilo Cyberpunk 2077 con ADN Command (docs/DISENO.md).

Base de Command: Void y la matriz de puntos de 26 px. Sin wordmark: el logo ya está en la barra,
el arranque y el bloqueo, y el fondo queda limpio bajo las ventanas.
Capa HUD: líneas de escaneo, un halo rojo muy tenue abajo, escuadras en las esquinas y un rótulo
pequeño en cian con su regla, arriba a la izquierda y por debajo de la barra.

Uso: python build/make-wallpaper.py  ->  os/branding/wallpapers/command-void.png
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent / "os" / "branding"
W, H, GRID = 2560, 1440, 26
VOID = (13, 11, 14)
DOT = (32, 27, 33)
RED = (209, 52, 73)
CYAN = (91, 191, 196)
CYAN_DIM = (47, 110, 114)
M = 56  # margen del marco HUD

img = Image.new("RGB", (W, H), VOID)

# Halo rojo muy tenue en la franja inferior.
glow = Image.new("L", (W, H), 0)
ImageDraw.Draw(glow).ellipse((W // 2 - 900, H - 360, W // 2 + 900, H + 260), fill=255)
glow = glow.filter(ImageFilter.GaussianBlur(220)).point(lambda a: int(a * 0.08))
img.paste(Image.new("RGB", (W, H), RED), (0, 0), glow)

d = ImageDraw.Draw(img, "RGBA")

# Matriz de puntos de Command.
for y in range(GRID // 2, H, GRID):
    for x in range(GRID // 2, W, GRID):
        d.ellipse((x - 1, y - 1, x + 1, y + 1), fill=DOT)

# Líneas de escaneo: una de cada 4 px, apenas perceptible.
for y in range(0, H, 4):
    d.line((0, y, W, y), fill=(0, 0, 0, 38))

# Escuadras en las cuatro esquinas.
L, T = 44, 2
for cx, cy, sx, sy in ((M, M, 1, 1), (W - M, M, -1, 1), (M, H - M, 1, -1), (W - M, H - M, -1, -1)):
    d.line((cx, cy, cx + sx * L, cy), fill=RED + (150,), width=T)
    d.line((cx, cy, cx, cy + sy * L), fill=RED + (150,), width=T)

font_path = ROOT / "fonts" / "Oxanium[wght].ttf"
small = ImageFont.truetype(str(font_path), 18)
try:
    small.set_variation_by_axes([600])
except OSError:
    pass

# Rótulo arriba a la izquierda + regla con marcas, con aire bajo la barra de Waybar.
LY = M + 64
d.text((M + 18, LY), "cmd-os  //  command os", font=small, fill=CYAN + (170,))
for i in range(24):
    x = M + 18 + i * 12
    d.line((x, LY + 34, x, LY + (44 if i % 6 == 0 else 38)), fill=CYAN_DIM + (200,), width=1)

out = ROOT / "wallpapers" / "command-void.png"
img.save(out, optimize=True)
print(out, out.stat().st_size)
