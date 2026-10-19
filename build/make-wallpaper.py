"""Genera los fondos de Command OS con el lenguaje de la marca v2 (docs/DISENO.md § «Pantalla»; BRAND.md
§§ 3, 6 y 7 de command-web). Regla de función: nada de lecturas, números de serie ni adornos inventados.

- reticula (de serie): la retícula de puntos de 26 px con máscara radial, la C en el centro y un
  degradado rojo muy tenue (14 %) detrás de ella, como el héroe de la web.
- plano: la construcción real del símbolo sobre la rejilla de 64 px: el contorno de la C, las guías
  de sus medidas (tronco, brazos, hueco y barra), el área de respeto (¼ del ancho) y las cotas en
  unidades del viewBox. La barra es lo único rojo.
- void: Void con la retícula muy tenue, sin rojo; fondo del bloqueo, de GRUB y del asistente (ya
  llevan su propio logo encima).

La barra del símbolo es siempre Signal Red, con el único halo permitido (BRAND § 3: desenfoque de
≈ 2 % del ancho del símbolo, opacidad ≈ 55 %). Colores, solo los de la paleta v2 (tests/marca.sh).
Los de escritorio salen en 16:9 (2560x1440, command-<nombre>.png) y 16:10 (2560x1600,
command-<nombre>-16x10.png): cada pantalla usa el suyo y no se recorta (command-os-wallpaper). La
composición va en proporción al alto; la retícula y la rejilla, en píxeles fijos. void solo en 16:9:
es liso y se recorta sin perder nada.
Uso: python build/make-wallpaper.py [16x9|16x10]   (sin argumento, los dos)
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT / "os" / "branding"
OUT = REPO / "wallpapers"
W, H = 2560, 1440
SS = 2  # las líneas se dibujan al doble y se reducen: filos suaves de 1 px


def rgb(h):
    return np.array(list(bytes.fromhex(h[1:])), float)


VOID = rgb("#0E0E0E")
STEEL = rgb("#2A2A2A")
BONE = rgb("#EDEBE6")
WHITE = rgb("#FFFFFF")
SIGNAL = rgb("#A51500")
LINE_PLAN = 0.55  # --line-plan: Bone al 55 %
LINE_GUIDE = 0.16  # --line-guide: Bone al 16 %
MARK = Image.open(REPO / "logo" / "command-mark-white.png").convert("RGBA")
MONO = str(ROOT / "build" / "fonts" / "JetBrainsMono-Regular.ttf")  # OFL, solo para generar

# Medidas del símbolo en unidades de su viewBox (command-mark.svg, 1158 x 1237; el PNG va a 1:1):
# tronco de la C, brazos, hueco hasta la barra y barra. Se comprueban contra el PNG al cargarlo.
MW, MH = 1158, 1237
TRONCO = 251
BRAZO = 218
C_ALTO = 963
BARRA_Y = 1077
RESPETO = MW / 4


def a(im):
    return np.asarray(im, float) / 255.0


def mark_masks(height):
    """Máscaras de la C y de la barra, escaladas a `height` px de alto."""
    w = round(MARK.width * height / MARK.height)
    rgba = np.asarray(MARK.resize((w, height), Image.Resampling.LANCZOS), float)
    alpha = rgba[..., 3] / 255.0
    is_c = (rgba[..., 1] > 128).astype(float)  # la C es blanca; la barra, roja
    c = Image.fromarray((alpha * is_c * 255).astype(np.uint8))
    bar = Image.fromarray((alpha * (1 - is_c) * 255).astype(np.uint8))
    return c, bar


def check_mark():
    """Las medidas de arriba son las del PNG del símbolo (si cambia el logo, se rehacen)."""
    px = np.asarray(MARK, float)
    c = (px[..., 3] > 128) & (px[..., 1] > 128)
    bar = (px[..., 3] > 128) & ~(px[..., 1] > 128)
    assert MARK.size == (MW, MH), MARK.size
    assert abs(np.nonzero(c[MH * 2 // 5])[0].max() + 1 - TRONCO) <= 2
    assert abs(np.nonzero(c[:, MW // 2])[0][np.nonzero(np.diff(c[:, MW // 2].astype(int)))[0][0]] + 1 - BRAZO) <= 2
    assert abs(np.nonzero(c.any(1))[0].max() + 1 - C_ALTO) <= 2
    assert abs(np.nonzero(bar.any(1))[0].min() - BARRA_Y) <= 2


def place(mask, x, y):
    canvas = Image.new("L", (W, H), 0)
    canvas.paste(mask, (x, y))
    return canvas


def radial(cx, cy, rx, ry):
    """Distancia elíptica normalizada al punto (cx, cy): 0 en el centro, 1 en el borde de la elipse."""
    gy, gx = np.mgrid[0:H, 0:W]
    return np.sqrt(((gx - cx) / rx) ** 2 + ((gy - cy) / ry) ** 2)


def dots(step=26, r=1.1):
    """Retícula de puntos de la marca (Steel sobre Void en la web), como máscara 0..1."""
    big = Image.new("L", (W * SS, H * SS), 0)
    d = ImageDraw.Draw(big)
    rr = r * SS
    for y in range(step // 2, H, step):
        for x in range(step // 2, W, step):
            d.ellipse((x * SS - rr, y * SS - rr, x * SS + rr, y * SS + rr), fill=255)
    return a(big.resize((W, H), Image.Resampling.BOX))


def put_mark(img, height, cx, cy):
    """La C en blanco y la barra en Signal Red con su halo; devuelve la caja del símbolo."""
    c, bar = mark_masks(height)
    x0, y0 = round(cx - c.width / 2), round(cy - height / 2)
    cm, bm = a(place(c, x0, y0))[..., None], place(bar, x0, y0)
    halo = a(bm.filter(ImageFilter.GaussianBlur(0.02 * c.width)))[..., None]
    img += halo * SIGNAL * 0.55
    img[:] = img * (1 - cm) + cm * WHITE
    bma = a(bm)[..., None]
    img[:] = img * (1 - bma) + bma * SIGNAL
    return x0, y0, c.width, height


def done(img):
    return Image.fromarray(np.clip(np.round(img), 0, 255).astype(np.uint8))


# ----------------------------------------------------------------- reticula
def reticula():
    img = np.ones((H, W, 3)) * VOID
    cx, cy = W / 2, H * 0.48
    fade = np.clip(1.25 - radial(cx, cy, W * 0.62, H * 0.75), 0, 1) ** 1.4  # máscara radial
    img += (dots() * fade)[..., None] * (STEEL - VOID)
    red = np.clip(1 - radial(cx, cy, H * 0.75, H * 0.6), 0, 1) ** 2  # rojo ≤ 14 %
    img += (red * 0.14)[..., None] * (SIGNAL - VOID)
    put_mark(img, round(H * 0.24), cx, cy)
    return done(img)


# --------------------------------------------------------------------- plano
def plano():
    img = np.ones((H, W, 3)) * VOID
    hm = round(H * 0.40)
    s = hm / MH
    cx, cy = W / 2, H * 0.47
    x0, y0 = round(cx - MW * s / 2), round(cy - hm / 2)
    # La rejilla de 64 px pasa por la esquina del símbolo: el dibujo está construido sobre ella.
    grid = Image.new("L", (W * SS, H * SS), 0)
    gd = ImageDraw.Draw(grid)
    for x in range(x0 % 64, W, 64):
        gd.line((x * SS, 0, x * SS, H * SS), fill=255, width=SS)
    for y in range(y0 % 64, H, 64):
        gd.line((0, y * SS, W * SS, y * SS), fill=255, width=SS)
    fade = np.clip(1.15 - radial(cx, cy, W * 0.6, H * 0.8), 0, 1)
    img += (a(grid.resize((W, H), Image.Resampling.BOX)) * fade * 0.07)[..., None] * BONE

    # Guías (--line-guide) a lo largo de todo el plano y área de respeto discontinua.
    u = lambda v: v * s * SS  # unidades del viewBox a píxeles del lienzo grande
    X0, Y0 = x0 * SS, y0 * SS
    guides = Image.new("L", (W * SS, H * SS), 0)
    gd = ImageDraw.Draw(guides)
    for vx in (0, TRONCO, MW):
        gd.line((X0 + u(vx), 0, X0 + u(vx), H * SS), fill=255, width=SS)
    for vy in (0, BRAZO, C_ALTO - BRAZO, C_ALTO, BARRA_Y, MH):
        gd.line((0, Y0 + u(vy), W * SS, Y0 + u(vy)), fill=255, width=SS)
    rl, rt, rr, rb = X0 - u(RESPETO), Y0 - u(RESPETO), X0 + u(MW + RESPETO), Y0 + u(MH + RESPETO)
    dash = 12 * SS
    for t in np.arange(rl, rr, dash * 2):
        gd.line((t, rt, min(t + dash, rr), rt), fill=255, width=SS)
        gd.line((t, rb, min(t + dash, rr), rb), fill=255, width=SS)
    for t in np.arange(rt, rb, dash * 2):
        gd.line((rl, t, rl, min(t + dash, rb)), fill=255, width=SS)
        gd.line((rr, t, rr, min(t + dash, rb)), fill=255, width=SS)
    img += (a(guides.resize((W, H), Image.Resampling.BOX)) * LINE_GUIDE)[..., None] * (BONE - VOID)

    # Cotas (--line-plan): líneas con topes y la medida en unidades del viewBox.
    plan = Image.new("L", (W * SS, H * SS), 0)
    pd = ImageDraw.Draw(plan)
    font = ImageFont.truetype(MONO, round(H * 0.0125) * SS)
    tick = 8 * SS

    def cota_h(xa, xb, y, texto):
        pd.line((xa, y, xb, y), fill=255, width=SS)
        for x in (xa, xb):
            pd.line((x, y - tick, x, y + tick), fill=255, width=SS)
        pd.text(((xa + xb) / 2, y - tick * 1.5), texto, font=font, fill=255, anchor="md")

    def cota_v(ya, yb, x, texto, lado=1):
        pd.line((x, ya, x, yb), fill=255, width=SS)
        for y in (ya, yb):
            pd.line((x - tick, y, x + tick, y), fill=255, width=SS)
        pd.text((x + lado * tick * 1.5, (ya + yb) / 2), texto, font=font, fill=255,
                anchor="lm" if lado > 0 else "rm")

    top = Y0 - u(RESPETO) / 2
    cota_h(X0, X0 + u(MW), top, f"{MW}")
    cota_h(X0, X0 + u(TRONCO), Y0 + u(MH + RESPETO / 2), f"{TRONCO}")
    cota_h(X0 - u(RESPETO), X0, Y0 + u(MH / 2), "¼")
    right = X0 + u(MW + RESPETO / 2)
    cota_v(Y0, Y0 + u(MH), X0 + u(MW + RESPETO) + 24 * SS, f"{MH}")
    cota_v(Y0, Y0 + u(BRAZO), right, f"{BRAZO}")
    cota_v(Y0 + u(C_ALTO), Y0 + u(BARRA_Y), right, f"{BARRA_Y - C_ALTO}")
    cota_v(Y0 + u(BARRA_Y), Y0 + u(MH), right, f"{MH - BARRA_Y}")
    img += (a(plan.resize((W, H), Image.Resampling.BOX)) * LINE_PLAN)[..., None] * (BONE - VOID)

    # El símbolo dibujado en línea (--line-plan) y la barra, lo único rojo, con su halo.
    c, bar = mark_masks(hm)
    cm = place(c, x0, y0)
    edge = np.clip(a(cm) - a(cm.filter(ImageFilter.MinFilter(3))), 0, 1)
    img += (edge * LINE_PLAN)[..., None] * (BONE - VOID)
    bm = place(bar, x0, y0)
    img += a(bm.filter(ImageFilter.GaussianBlur(0.02 * c.width)))[..., None] * SIGNAL * 0.55
    bma = a(bm)[..., None]
    img = img * (1 - bma) + bma * SIGNAL
    return done(img)


# ---------------------------------------------------------------------- void
def void():
    img = np.ones((H, W, 3)) * VOID
    fade = np.clip(1.1 - radial(W / 2, H / 2, W * 0.6, H * 0.8), 0, 1) ** 1.6
    img += (dots() * fade * 0.6)[..., None] * (STEEL - VOID)
    return done(img)


FORMATOS = {"16x9": ((2560, 1440), ""), "16x10": ((2560, 1600), "-16x10")}

if __name__ == "__main__":
    check_mark()
    OUT.mkdir(parents=True, exist_ok=True)
    for formato in sys.argv[1:] or list(FORMATOS):
        (W, H), sufijo = FORMATOS[formato]
        for name, fn in (("reticula", reticula), ("plano", plano)):
            path = OUT / f"command-{name}{sufijo}.png"
            fn().save(path, optimize=True)
            print(path, path.stat().st_size)
        if formato == "16x9":
            path = OUT / "command-void.png"
            void().save(path, optimize=True)
            print(path, path.stat().st_size)
