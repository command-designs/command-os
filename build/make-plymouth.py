"""Genera los fotogramas del splash de arranque (BRAND.md § 9, firma 2 / § 12 ancla 2).

El wordmark se revela de izquierda a derecha y después la barra roja se extiende
desde la izquierda. Salida: os/branding/plymouth/command/frame-N.png, px-red.png y px-dim.png
(estos dos últimos son la barra de progreso de la consola de arranque de command.script).
"""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent / "os" / "branding"
OUT = ROOT / "plymouth" / "command"
OUT.mkdir(parents=True, exist_ok=True)

W = 640
REVEAL, BAR = 18, 10  # fotogramas de revelado de letras y de extensión de la barra
RED = (165, 21, 0, 255)  # Signal Red

src = Image.open(ROOT / "logo" / "command-wordmark-white.png").convert("RGBA")
H = round(src.height * W / src.width)
src = src.resize((W, H), Image.Resampling.LANCZOS)

# El PNG trae la barra roja en la franja inferior; se separa para animarla aparte.
bar_h = max(2, round(H * 22 / 223))
letters = src.crop((0, 0, W, H - bar_h))

def ease(t):  # ease-out, aprox. cubic-bezier(.16,1,.3,1)
    return 1 - (1 - t) ** 4

n = 0
for i in range(REVEAL + BAR):
    f = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    x = round(W * ease(min(1, (i + 1) / REVEAL)))
    f.paste(letters.crop((0, 0, x, letters.height)), (0, 0))
    if i >= REVEAL:
        bx = round(W * ease((i - REVEAL + 1) / BAR))
        ImageDraw.Draw(f).rounded_rectangle((0, H - bar_h, bx, H), radius=3, fill=RED)
    f.save(OUT / f"frame-{n}.png")
    n += 1
print(n, "fotogramas", W, "x", H)

# Píxeles sueltos para la barra de progreso del script (se escalan en Plymouth).
Image.new("RGBA", (1, 1), RED).save(OUT / "px-red.png")
Image.new("RGBA", (1, 1), (58, 58, 58, 255)).save(OUT / "px-dim.png")
