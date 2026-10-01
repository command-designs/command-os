"""Genera el wallpaper de Command OS (matriz de puntos de BRAND.md § 7).

Uso: python build/make-wallpaper.py  ->  os/branding/wallpapers/command-void.png
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent / "os" / "branding"
W, H, GRID = 2560, 1440, 26
VOID, DOT = (14, 14, 14), (34, 34, 34)

img = Image.new("RGB", (W, H), VOID)
d = ImageDraw.Draw(img)
for y in range(GRID // 2, H, GRID):
    for x in range(GRID // 2, W, GRID):
        d.ellipse((x - 1, y - 1, x + 1, y + 1), fill=DOT)

word = Image.open(ROOT / "logo" / "command-wordmark-white.png").convert("RGBA")
ww = 360
word = word.resize((ww, round(word.height * ww / word.width)), Image.Resampling.LANCZOS)
# Wordmark al 55 % de opacidad: presencia sin competir con las ventanas.
alpha = word.getchannel("A").point(lambda a: int(a * 0.55))
word.putalpha(alpha)
# Centrado: con `fit_mode = cover` en pantallas 4:3 se recortan los lados.
img.paste(word, ((W - word.width) // 2, H - 96 - word.height), word)

out = ROOT / "wallpapers" / "command-void.png"
img.save(out, optimize=True)
print(out, out.stat().st_size)
