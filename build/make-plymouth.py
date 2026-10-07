"""Genera los fotogramas del splash de arranque (BRAND.md § 9, firma 2 / § 12 ancla 2).

Firma de Command: el wordmark se revela de izquierda a derecha y después la barra roja se extiende
desde la izquierda (28 fotogramas, ~1,1 s). Capa HUD (docs/DISENO.md): un cursor cian marca el
borde del revelado y en tres fotogramas hay un glitch (franjas desplazadas + aberración
cromática roja/cian). El último fotograma queda limpio.
Salida: os/branding/plymouth/command/frame-N.png, px-red.png y px-dim.png (estos dos últimos son
la barra de progreso de la consola de arranque de command.script).
Van a doble resolución (wordmark de 1280 px): command.script los reduce al tamaño de cada pantalla,
así se ven nítidos también en alta densidad y en 4K.
"""
import random
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent / "os" / "branding"
OUT = ROOT / "plymouth" / "command"
OUT.mkdir(parents=True, exist_ok=True)

S = 2  # doble resolución: command.script los reduce según la pantalla
W = 640 * S
REVEAL, BAR = 18, 10  # fotogramas de revelado de letras y de extensión de la barra
SIGNAL_RED = (165, 21, 0, 255)  # barra del logo: no se recolorea (ancla 1)
RED = (209, 52, 73, 255)  # rojo 2077 del HUD
CYAN = (91, 191, 196)
STEEL = (46, 38, 48, 255)
GLITCH = {5: 1, 11: 2, 20: 3}  # fotograma -> semilla
PAD = 16 * S  # margen transparente para que quepan el halo y los desplazamientos del glitch

src = Image.open(ROOT / "logo" / "command-wordmark-white.png").convert("RGBA")
H = round(src.height * W / src.width)
src = src.resize((W, H), Image.Resampling.LANCZOS)

# El PNG trae la barra roja en la franja inferior; se separa para animarla aparte.
bar_h = max(2, round(H * 22 / 223))
letters = src.crop((0, 0, W, H - bar_h))


def ease(t):  # ease-out, aprox. cubic-bezier(.16,1,.3,1)
    return 1 - (1 - t) ** 4


def tint(img, rgb, opacity):
    out = Image.new("RGBA", img.size, rgb + (0,))
    out.putalpha(img.getchannel("A").point(lambda a: int(a * opacity)))
    return out


def glitch(frame, seed):
    """Aberración cromática + 3-4 franjas horizontales desplazadas."""
    rnd = random.Random(seed)
    out = Image.new("RGBA", frame.size, (0, 0, 0, 0))
    out.alpha_composite(tint(frame, CYAN, 0.7), (-4 * S, 0))
    out.alpha_composite(tint(frame, RED[:3], 0.7), (4 * S, 0))
    out.alpha_composite(frame)
    for _ in range(rnd.randint(3, 4)):
        y = rnd.randrange(0, frame.height - 8 * S)
        h = rnd.randint(3, 10) * S
        dx = rnd.choice((-1, 1)) * rnd.randint(6, 16) * S
        band = out.crop((0, y, frame.width, y + h))
        out.paste((0, 0, 0, 0), (0, y, frame.width, y + h))
        out.alpha_composite(band, (dx if dx > 0 else 0, y), (0 if dx > 0 else -dx, 0))
    return out


n = 0
for i in range(REVEAL + BAR):
    f = Image.new("RGBA", (W + 2 * PAD, H + 2 * PAD), (0, 0, 0, 0))
    d = ImageDraw.Draw(f)
    x = round(W * ease(min(1, (i + 1) / REVEAL)))
    f.alpha_composite(letters.crop((0, 0, x, letters.height)), (PAD, PAD))
    # Cursor cian en el borde del revelado mientras avanza.
    if x < W - 2 * S:
        d.rectangle((PAD + x, PAD - 4 * S, PAD + x + 2 * S, PAD + letters.height + 4 * S), fill=CYAN + (230,))
    if i >= REVEAL:
        bx = round(W * ease((i - REVEAL + 1) / BAR))
        bar = Image.new("RGBA", f.size, (0, 0, 0, 0))
        ImageDraw.Draw(bar).rectangle((PAD, PAD + H - bar_h, PAD + bx, PAD + H), fill=SIGNAL_RED)
        # Halo rojo bajo la barra.
        halo = tint(bar, RED[:3], 0.45).filter(ImageFilter.GaussianBlur(6 * S))
        f.alpha_composite(halo)
        f.alpha_composite(bar)
    if i in GLITCH:
        f = glitch(f, GLITCH[i])
    f.save(OUT / f"frame-{n}.png")
    n += 1
print(n, "fotogramas", W + 2 * PAD, "x", H + 2 * PAD)

# Píxeles sueltos para la barra de progreso del script (se escalan en Plymouth).
Image.new("RGBA", (1, 1), RED).save(OUT / "px-red.png")
Image.new("RGBA", (1, 1), STEEL).save(OUT / "px-dim.png")
