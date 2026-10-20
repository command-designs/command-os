"""Genera los fondos de Command OS con el lenguaje de la marca v2 (docs/DISENO.md § «Fondos»; BRAND.md
§§ 3, 6 y 7 de command-web). Regla de función: nada de lecturas, números de serie ni adornos inventados.

- reticula (de serie): la retícula de puntos de 26 px con máscara radial, la C en el centro y un
  degradado rojo muy tenue (14 %) detrás de ella, como el héroe de la web.
- plano: el plano holográfico de lenguaje.html (§ 02) con la construcción real del símbolo, sobre la
  retícula de puntos y la rejilla de 64 px: el contorno de la C en --holo, las guías de sus medidas
  (tronco, brazos, hueco y barra) y el área de respeto (¼ del ancho) en --holo-dim, y llamadas
  quebradas que terminan en una etiqueta mono y explican cada pieza con su medida en unidades del
  viewBox. La barra es lo único rojo; su llamada, la única en Red Hot, con el halo de #hudglow.
- void: Void con la retícula muy tenue, sin rojo; fondo del bloqueo, de GRUB y del asistente (ya
  llevan su propio logo encima).

La barra del símbolo es siempre Signal Red, con su halo (BRAND § 3: desenfoque de ≈ 2 % del ancho
del símbolo, opacidad ≈ 55 %); el otro halo, el de la llamada roja del plano (BRAND 2.1 § 7.2). Colores, solo los de la paleta v2 (tests/marca.sh).
Los de escritorio salen en 16:9 (2560x1440, command-<nombre>.png) y 16:10 (2560x1600,
command-<nombre>-16x10.png): cada pantalla usa el suyo y no se recorta (command-os-wallpaper). La
composición va en proporción al alto; la retícula y la rejilla, en píxeles fijos. void solo en 16:9:
es liso y se recorta sin perder nada.
Las etiquetas del plano van en JetBrains Mono Medium (la de la marca, peso 500): se toma la del sistema
(ttf-jetbrains-mono-nerd en Arch, o la de Windows); build/fonts solo trae la Regular.
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
RED_HOT = rgb("#F5482C")
ASH = rgb("#A3A09A")
HOLO = 0.55  # --holo: Bone al 55 % (trazo del plano)
HOLO_DIM = 0.18  # --holo-dim: Bone al 18 % (guías y llamadas)
MARK = Image.open(REPO / "logo" / "command-mark-white.png").convert("RGBA")
MEDIUM = [  # JetBrains Mono Medium del sistema (OFL), solo para generar
    "/usr/share/fonts/TTF/JetBrainsMonoNLNerdFont-Medium.ttf",
    "C:/Windows/Fonts/JetBrainsMonoNLNerdFont-Medium.ttf",
    str(Path.home() / "AppData/Local/Microsoft/Windows/Fonts/JetBrainsMonoNLNerdFont-Medium.ttf"),
]

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
def mono_medium():
    for ruta in MEDIUM:
        if Path(ruta).exists():
            return ruta
    sys.exit("falta JetBrains Mono Medium (ttf-jetbrains-mono-nerd): " + ", ".join(MEDIUM))


def plano():
    img = np.ones((H, W, 3)) * VOID
    hm = round(H * 0.40)
    s = hm / MH
    cx, cy = W / 2, H * 0.47
    x0, y0 = round(cx - MW * s / 2), round(cy - hm / 2)
    big = (W * SS, H * SS)

    # Fondo del héroe de lenguaje.html: retícula de puntos y rejilla de 64 px (que pasa por la esquina
    # del símbolo: el dibujo está construido sobre ella) con máscara radial, y un degradado rojo muy
    # tenue (≤ 14 %) detrás del símbolo.
    grid = Image.new("L", big, 0)
    gd = ImageDraw.Draw(grid)
    for x in range(x0 % 64, W, 64):
        gd.line((x * SS, 0, x * SS, H * SS), fill=255, width=SS)
    for y in range(y0 % 64, H, 64):
        gd.line((0, y * SS, W * SS, y * SS), fill=255, width=SS)
    fade = np.clip(1.15 - radial(cx, cy, W * 0.6, H * 0.8), 0, 1)
    img += (a(grid.resize((W, H), Image.Resampling.BOX)) * fade * 0.05)[..., None] * BONE
    img += (dots() * fade * 0.07)[..., None] * (BONE - VOID)
    red = np.clip(1 - radial(cx, cy, H * 0.55, H * 0.5), 0, 1) ** 2
    img += (red * 0.14)[..., None] * (SIGNAL - VOID)

    u = lambda v: v * s * SS  # unidades del viewBox a píxeles del lienzo grande
    X0, Y0 = x0 * SS, y0 * SS
    rl, rt, rr, rb = X0 - u(RESPETO), Y0 - u(RESPETO), X0 + u(MW + RESPETO), Y0 + u(MH + RESPETO)
    ancho = round(1.5 * SS)  # trazo del plano: 1,2 px a la escala de la referencia

    # Guías (--holo-dim) de las medidas, hasta un poco más allá del área de respeto, y el área de
    # respeto discontinua.
    dim = Image.new("L", big, 0)
    dd = ImageDraw.Draw(dim)
    margen = 64 * SS
    for vx in (0, TRONCO, MW):
        dd.line((X0 + u(vx), rt - margen, X0 + u(vx), rb + margen), fill=255, width=SS)
    for vy in (0, BRAZO, C_ALTO - BRAZO, C_ALTO, BARRA_Y, MH):
        dd.line((rl - margen, Y0 + u(vy), rr + margen, Y0 + u(vy)), fill=255, width=SS)
    dash = 12 * SS
    for t_ in np.arange(rl, rr, dash * 2):
        dd.line((t_, rt, min(t_ + dash, rr), rt), fill=255, width=SS)
        dd.line((t_, rb, min(t_ + dash, rr), rb), fill=255, width=SS)
    for t_ in np.arange(rt, rb, dash * 2):
        dd.line((rl, t_, rl, min(t_ + dash, rb)), fill=255, width=SS)
        dd.line((rr, t_, rr, min(t_ + dash, rb)), fill=255, width=SS)

    # Llamadas: línea quebrada (recta, 45° y recta) que sale de la pieza y termina en su etiqueta mono
    # en mayúsculas (peso 500, 0,16 em), con la medida debajo. Solo la de la barra va en Red Hot.
    rojo = Image.new("L", big, 0)
    rd = ImageDraw.Draw(rojo)
    texto_ash = Image.new("L", big, 0)
    texto_rojo = Image.new("L", big, 0)
    letra = round(H * 0.0105) * SS
    fuente = ImageFont.truetype(mono_medium(), letra)
    paso = 0.16 * letra

    def escribir(capa, x, y, texto, derecha=False):
        anchos = [fuente.getlength(c) + paso for c in texto]
        total = sum(anchos) - paso
        x = x - total if derecha else x
        d = ImageDraw.Draw(capa)
        for c, w in zip(texto, anchos):
            d.text((x, y), c, font=fuente, fill=255, anchor="ls")
            x += w

    def llamada(px, py, lado, nombre, medida, caliente=False):
        """Desde (px, py) del lienzo grande hacia `lado` (+1 derecha, -1 izquierda)."""
        borde = rr if lado > 0 else rl
        x1 = borde + lado * 48 * SS
        sube = 28 * SS
        x2 = x1 + lado * sube
        x3 = x2 + lado * 230 * SS
        y2 = py - sube
        trazo = rd if caliente else dd
        trazo.line([(px, py), (x1, py), (x2, y2), (x3, y2)], fill=255,
                   width=round(2 * SS) if caliente else SS, joint="curve")
        xt = x2 + lado * 6 * SS
        escribir(texto_rojo if caliente else texto_ash, xt, y2 - 10 * SS, nombre, derecha=lado < 0)
        escribir(texto_ash, xt, y2 + letra + 10 * SS, medida, derecha=lado < 0)

    llamada(X0 + u(MW), Y0 + u(BRAZO / 2), +1, "BRAZO", f"ALTO {BRAZO}")
    llamada(X0 + u((TRONCO + MW) / 2), Y0 + u(C_ALTO / 2), +1, "HUECO", f"ALTO {C_ALTO - 2 * BRAZO}")
    llamada(X0 + u(MW), Y0 + u((BARRA_Y + MH) / 2), +1, "BARRA", f"ALTO {MH - BARRA_Y} · ÚNICO ROJO",
            caliente=True)
    llamada(X0 + u(TRONCO / 2), Y0 + u(C_ALTO / 2), -1, "TRONCO", f"ANCHO {TRONCO}")
    llamada(rl, Y0 + u(MH * 0.12), -1, "ÁREA DE RESPETO", "¼ DEL ANCHO")
    pie = f"SÍMBOLO C · {MW} × {MH}"
    escribir(texto_ash, (X0 + u(MW / 2)) - sum(fuente.getlength(c) + paso for c in pie) / 2 + paso / 2,
             rb + 56 * SS, pie)

    baja = lambda capa: a(capa.resize((W, H), Image.Resampling.BOX))
    img += (baja(dim) * HOLO_DIM)[..., None] * (BONE - VOID)
    img += (baja(texto_ash))[..., None] * (ASH - VOID)

    # El símbolo dibujado en línea (--holo).
    c, bar = mark_masks(hm)
    cm = place(c, x0, y0)
    edge = np.clip(a(cm) - a(cm.filter(ImageFilter.MinFilter(3))), 0, 1)
    img += (edge * HOLO)[..., None] * (BONE - VOID)

    # La llamada roja con el halo de #hudglow (feGaussianBlur 2, opacidad .5) y su etiqueta.
    r = baja(rojo)
    img += (a(Image.fromarray((r * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(2))) * 0.5)[..., None] * RED_HOT
    img = img * (1 - r[..., None]) + r[..., None] * RED_HOT
    tr = baja(texto_rojo)[..., None]
    img = img * (1 - tr) + tr * RED_HOT

    # La barra, lo único rojo del símbolo, en Signal Red con su halo.
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
