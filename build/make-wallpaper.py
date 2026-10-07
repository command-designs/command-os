"""Genera los fondos de Command OS (docs/DISENO.md): gráfica de producto, como la que traería de serie
un ordenador fabricado en el mundo de Cyberpunk, no paisajes.

- interfaz (de serie): corte diagonal con filo rojo, trama de semitono, wordmark en contorno, la C
  con microtipografía de fabricante y dos cortes con glitch.
- nucleo: la C como pieza de hardware retroiluminada, de la que salen pistas de circuito.
- placa: macro de la placa del cyberdeck con el chip serigrafiado, con desenfoque de cámara.
- void: Void con la matriz de puntos tenue y un resplandor rojo bajo; fondo del bloqueo y de GRUB
  (ya llevan su propio logo encima).

La barra del símbolo es siempre Signal Red (#A51500); su resplandor, el rojo de la marca.
Los de escritorio salen en 16:9 (2560x1440, command-<nombre>.jpg) y 16:10 (2560x1600,
command-<nombre>-16x10.jpg): cada pantalla usa el suyo y no se recorta (command-os-wallpaper). La
composición va en proporción al lienzo. void solo en 16:9: es liso y se recorta sin perder nada.
Uso: python build/make-wallpaper.py [16x9|16x10]   (sin argumento, los dos)
"""
import math
import random
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parent.parent
REPO = ROOT / "os" / "branding"
OUT = REPO / "wallpapers"
W, H = 2560, 1440
VOID = np.array([13, 11, 14], float)
GRAPHITE = np.array([21, 18, 26], float)
SLATE = np.array([29, 24, 32], float)
STEEL = np.array([46, 38, 48], float)
RED = np.array([209, 52, 73], float)
SIGNAL = np.array([165, 21, 0], float)
CYAN = np.array([91, 191, 196], float)
BONE = np.array([237, 235, 230], float)
MAROON = np.array([43, 17, 24], float)
MARK = Image.open(REPO / "logo" / "command-mark-white.png").convert("RGBA")
WORD = Image.open(REPO / "logo" / "command-wordmark-white.png").convert("RGBA")
FONT = str(REPO / "fonts" / "Oxanium[wght].ttf")
MONO = str(ROOT / "build" / "fonts" / "JetBrainsMono-Regular.ttf")  # OFL, solo para generar


def a(im):
    return np.asarray(im, float) / 255.0


def blur(im, r):
    return a(im.filter(ImageFilter.GaussianBlur(r)))


def glow(img, mask_im, color, core=1.0, near=(8, 0.9), far=(50, 0.5)):
    img += a(mask_im)[..., None] * color * core
    img += blur(mask_im, near[0])[..., None] * color * near[1]
    img += blur(mask_im, far[0])[..., None] * color * far[1]


def bar_light(img, mask_im, near=14, far=80, k=1.0):
    """La barra del símbolo: núcleo en Signal Red exacto y resplandor en el rojo de la marca."""
    m = a(mask_im)[..., None]
    halo = blur(mask_im, near)[..., None] * 0.55 + blur(mask_im, far)[..., None] * 0.45
    img += halo * RED * 0.75 * k
    img[:] = img * (1 - m) + m * SIGNAL * 1.08


def finish(img, seed, vignette=0.38, grain=2.2):
    gy, gx = np.mgrid[0:H, 0:W]
    r = np.sqrt(((gx - W / 2) / (W / 2)) ** 2 + ((gy - H / 2) / (H / 2)) ** 2)
    img *= (1 - vignette * np.clip(r - 0.5, 0, 1))[..., None]
    img += np.random.default_rng(seed).normal(0, grain, (H, W, 1))
    return Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))


def mark_masks(height):
    """Máscaras de la C y de la barra del símbolo, escaladas a `height` px de alto."""
    w = round(MARK.width * height / MARK.height)
    m = MARK.resize((w, height), Image.Resampling.LANCZOS)
    rgba = np.asarray(m, float)
    alpha = rgba[..., 3] / 255.0
    is_c = (rgba[..., 1] > 128).astype(float)  # la C es blanca; la barra, roja
    c = Image.fromarray((alpha * is_c * 255).astype(np.uint8))
    bar = Image.fromarray((alpha * (1 - is_c) * 255).astype(np.uint8))
    return c, bar


def place(mask, x, y):
    canvas = Image.new("L", (W, H), 0)
    canvas.paste(mask, (x, y))
    return canvas


def trace_path(rnd, x, y, steps, step_len, dirs):
    pts = [(x, y)]
    d = rnd.choice(dirs)
    for _ in range(steps):
        if rnd.random() < 0.35:
            d = rnd.choice(dirs)
        x += d[0] * step_len
        y += d[1] * step_len
        pts.append((x, y))
    return pts


# ------------------------------------------------------------------ 1. núcleo
def nucleo():
    rnd = random.Random(1)
    img = np.ones((H, W, 3)) * VOID
    cx, cy = int(W * 0.5), int(H * 0.47)
    # Fondo: foco granate detrás del símbolo.
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).ellipse((cx - 900, cy - 700, cx + 900, cy + 700), fill=255)
    img += blur(m, 320)[..., None] * MAROON * 1.1

    # Pistas que salen del símbolo hacia los bordes, a 0/45/90 grados.
    dim = Image.new("L", (W, H), 0)
    lit_r = Image.new("L", (W, H), 0)
    lit_c = Image.new("L", (W, H), 0)
    dd, dr, dc = ImageDraw.Draw(dim), ImageDraw.Draw(lit_r), ImageDraw.Draw(lit_c)
    dirs8 = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)]
    for _ in range(140):
        ang = rnd.uniform(0, 2 * math.pi)
        sx, sy = cx + math.cos(ang) * 360, cy + math.sin(ang) * 300
        # sesgo hacia fuera
        out = (round(math.cos(ang)), round(math.sin(ang)))
        dirs = [out, out, out] + [d for d in dirs8 if d[0] * out[0] + d[1] * out[1] > 0]
        pts = trace_path(rnd, sx, sy, rnd.randint(8, 22), rnd.choice((30, 40, 50)), dirs)
        dd.line(pts, fill=90, width=2)
        ex, ey = pts[-1]
        dd.ellipse((ex - 5, ey - 5, ex + 5, ey + 5), outline=110, width=2)
        k = rnd.random()
        if k < 0.10:
            seg = pts[: rnd.randint(3, len(pts))]
            dr.line(seg, fill=255, width=2)
        elif k < 0.16:
            seg = pts[: rnd.randint(3, len(pts))]
            dc.line(seg, fill=255, width=2)
    img += a(dim)[..., None] * STEEL * 0.9
    glow(img, lit_r, RED, 0.85, (6, 0.7), (30, 0.35))
    glow(img, lit_c, CYAN, 0.7, (6, 0.6), (30, 0.3))

    # Aro técnico fino alrededor.
    ring = Image.new("L", (W, H), 0)
    rd = ImageDraw.Draw(ring)
    rd.ellipse((cx - 470, cy - 470, cx + 470, cy + 470), outline=120, width=1)
    for t in range(0, 360, 3):
        r1, r2 = (470, 488) if t % 30 == 0 else (470, 478)
        ca, sa = math.cos(math.radians(t)), math.sin(math.radians(t))
        rd.line((cx + ca * r1, cy + sa * r1, cx + ca * r2, cy + sa * r2), fill=120, width=1)
    img += a(ring)[..., None] * CYAN * 0.35

    # El símbolo: cuerpo oscuro mate, filo de luz roja (contraluz) y la barra encendida.
    c, bar = mark_masks(560)
    x0, y0 = cx - c.width // 2, cy - 300
    cm, bm = place(c, x0, y0), place(bar, x0, y0)
    cma = a(cm)[..., None]
    body = np.ones((H, W, 3)) * SLATE
    shade = np.linspace(1.25, 0.65, H)[:, None, None]
    img = img * (1 - cma) + cma * body * shade
    edge = np.clip(a(cm) - blur(cm, 3), 0, 1) * 2.4
    edge_im = Image.fromarray((np.clip(edge, 0, 1) * 255).astype(np.uint8))
    glow(img, edge_im, RED, 0.9, (5, 0.6), (40, 0.35))
    bar_light(img, bm, 14, 90, 1.2)
    # Reflejo de la barra en un suelo invisible.
    by = int(np.nonzero(a(bm).sum(1))[0].max())
    floor = Image.new("L", (W, H), 0)
    floor.paste(bar.transpose(Image.Transpose.FLIP_TOP_BOTTOM), (x0, by + 40))
    img += blur(floor, 22)[..., None] * RED * 0.22
    return finish(img, 11)


# -------------------------------------------------------------------- 2. placa
def placa():
    rnd = random.Random(7)
    img = np.ones((H, W, 3)) * (GRAPHITE * 0.85)
    G = 24  # rejilla de rutado
    cx, cy = int(W * 0.56), int(H * 0.52)
    chip = (cx - 260, cy - 260, cx + 260, cy + 260)
    copper = Image.new("L", (W, H), 0)
    sig_r = Image.new("L", (W, H), 0)
    sig_c = Image.new("L", (W, H), 0)
    vias = Image.new("L", (W, H), 0)
    cd, sr, sc, vd = (ImageDraw.Draw(x) for x in (copper, sig_r, sig_c, vias))

    def bus(x, y, n, dirs, steps, step):
        base = trace_path(rnd, x, y, steps, step, dirs)
        for k in range(n):
            off = k * 12
            pts = [(px + (off if abs(base[1][1] - base[0][1]) > 0 else 0),
                    py + (off if abs(base[1][0] - base[0][0]) > 0 else 0)) for px, py in base]
            cd.line(pts, fill=255, width=3)
            ex, ey = pts[-1]
            vd.ellipse((ex - 6, ey - 6, ex + 6, ey + 6), outline=255, width=3)
            r = rnd.random()
            if r < 0.07:
                sr.line(pts[: rnd.randint(2, len(pts))], fill=255, width=3)
            elif r < 0.12:
                sc.line(pts[: rnd.randint(2, len(pts))], fill=255, width=3)

    # Pines del chip y buses que salen de cada lado.
    for side in range(4):
        for k in range(28):
            t = chip[0] + 30 + k * 16 if side in (0, 1) else chip[1] + 30 + k * 16
            if side == 0:
                x, y, d = t, chip[1], (0, -1)
            elif side == 1:
                x, y, d = t, chip[3], (0, 1)
            elif side == 2:
                x, y, d = chip[0], t, (-1, 0)
            else:
                x, y, d = chip[2], t, (1, 0)
            cd.line((x, y, x + d[0] * 26, y + d[1] * 26), fill=255, width=6)
            diag = [(d[0] + (d[1] != 0) * s, d[1] + (d[0] != 0) * s) for s in (-1, 1)]
            pts = [(x + d[0] * 26, y + d[1] * 26)]
            px, py = pts[0]
            for _ in range(rnd.randint(6, 30)):
                st = d if rnd.random() < 0.75 else rnd.choice(diag)
                px, py = px + st[0] * G, py + st[1] * G
                pts.append((px, py))
            cd.line(pts, fill=255, width=3)
            vd.ellipse((px - 6, py - 6, px + 6, py + 6), outline=255, width=3)
            r = rnd.random()
            if r < 0.09:
                sr.line(pts[: rnd.randint(2, len(pts))], fill=255, width=3)
            elif r < 0.15:
                sc.line(pts[: rnd.randint(2, len(pts))], fill=255, width=3)
    # Buses sueltos por la placa.
    dirs = [(1, 0), (0, 1), (1, 1), (-1, 1)]
    for _ in range(40):
        bus(rnd.randint(0, W), rnd.randint(0, H), rnd.randint(2, 6), dirs, rnd.randint(8, 25), G)
    # Componentes pasivos.
    for _ in range(160):
        x, y = rnd.randint(0, W), rnd.randint(0, H)
        if chip[0] - 60 < x < chip[2] + 60 and chip[1] - 60 < y < chip[3] + 60:
            continue
        w, h = rnd.choice(((22, 12), (12, 22), (34, 18)))
        cd.rectangle((x, y, x + 6, y + h), fill=255)
        cd.rectangle((x + w - 6, y, x + w, y + h), fill=255)
    cu = a(copper)[..., None]
    img = img * (1 - cu) + cu * (STEEL * 1.25)
    img += a(vias)[..., None] * STEEL * 1.4
    glow(img, sig_r, RED, 0.9, (5, 0.8), (26, 0.4))
    glow(img, sig_c, CYAN, 0.8, (5, 0.7), (26, 0.35))
    # El chip: encapsulado negro mate con la C serigrafiada y su barra.
    chm = Image.new("L", (W, H), 0)
    ImageDraw.Draw(chm).rectangle(chip, fill=255)
    cmask = a(chm)[..., None]
    grad = np.linspace(1.15, 0.8, H)[:, None, None]
    img = img * (1 - cmask) + cmask * VOID * 1.1 * grad
    ImageDraw.Draw(chm).rectangle((chip[0] + 3, chip[1] + 3, chip[2] - 3, chip[3] - 3), fill=0)
    img += a(chm)[..., None] * STEEL * 1.2  # canto del encapsulado
    c, bar = mark_masks(240)
    x0, y0 = cx - c.width // 2, cy - 150
    img += a(place(c, x0, y0))[..., None] * (BONE * 0.55)
    bar_light(img, place(bar, x0, y0), 8, 40, 0.9)
    txt = Image.new("L", (W, H), 0)
    td = ImageDraw.Draw(txt)
    td.text((chip[0] + 30, chip[3] - 70), "CMD-OS  C2077-A", font=ImageFont.truetype(MONO, 22), fill=200)
    td.text((chip[0] + 30, chip[3] - 42), "NC  2610  0x7E3", font=ImageFont.truetype(MONO, 18), fill=140)
    img += a(txt)[..., None] * BONE * 0.45
    # Profundidad de campo: nítido cerca del chip, desenfocado hacia los bordes.
    sharp = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
    soft = np.asarray(sharp.filter(ImageFilter.GaussianBlur(7)), float)
    gy, gx = np.mgrid[0:H, 0:W]
    dist = np.sqrt(((gx - cx) / (W * 0.55)) ** 2 + ((gy - cy) / (H * 0.55)) ** 2)
    k = np.clip((dist - 0.35) / 0.55, 0, 1)[..., None]
    img = img * (1 - k) + soft * k
    # Luz rasante desde arriba a la izquierda.
    img *= (1.05 - 0.25 * (gx / W + gy / H) / 2)[..., None]
    return finish(img, 22, vignette=0.45)


# ----------------------------------------------------------------- 3. interfaz
def interfaz():
    rnd = random.Random(3)
    img = np.ones((H, W, 3)) * VOID
    gy, gx = np.mgrid[0:H, 0:W]
    # Plano diagonal con degradado rojo.
    t = (gx * math.sin(math.radians(18)) + gy * math.cos(math.radians(18)))
    t = t / t.max()
    band = ((gx - gy * 0.32) > W * 0.42).astype(float)
    band_soft = a(Image.fromarray((band * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(1.2)))
    img += band_soft[..., None] * (MAROON * 1.5 - VOID) * (0.5 + 0.8 * (gy / H))[..., None]
    # Trama de semitono que se desvanece hacia arriba, solo dentro del plano.
    half = Image.new("L", (W, H), 0)
    hd = ImageDraw.Draw(half)
    step = 14
    for y in range(0, H, step):
        for x in range(0, W, step):
            if (x - y * 0.32) <= W * 0.42:
                continue
            rr = 5.2 * ((y / H) ** 1.6)
            if rr > 0.6:
                hd.ellipse((x - rr, y - rr, x + rr, y + rr), fill=255)
    img += a(half)[..., None] * RED * 0.35
    # Filo del plano en rojo, con brillo, y una línea cian paralela más fina.
    edge = Image.new("L", (W, H), 0)
    ImageDraw.Draw(edge).line((W * 0.42, 0, W * 0.42 + H * 0.32, H), fill=255, width=3)
    glow(img, edge, RED, 1.0, (6, 0.8), (40, 0.4))
    cl = Image.new("L", (W, H), 0)
    ImageDraw.Draw(cl).line((W * 0.40, 0, W * 0.40 + H * 0.32, H), fill=255, width=1)
    img += a(cl)[..., None] * CYAN * 0.7
    # Wordmark gigante recortado abajo a la izquierda, solo contorno.
    ww = int(W * 1.05)
    wm = WORD.resize((ww, round(WORD.height * ww / WORD.width)), Image.Resampling.LANCZOS)
    wa = np.asarray(wm, float)[..., 3]
    wm_l = Image.fromarray(wa.astype(np.uint8))
    out = np.clip(a(wm_l) - a(wm_l.filter(ImageFilter.MinFilter(5))), 0, 1)
    outline = Image.fromarray((out * 255).astype(np.uint8))
    big = Image.new("L", (W, H), 0)
    big.paste(outline, (-int(W * 0.08), int(H * 0.60)))
    img += a(big)[..., None] * BONE * 0.10
    # La C, sólida y a buen tamaño, en el plano rojo.
    c, bar = mark_masks(380)
    x0, y0 = int(W * 0.72), int(H * 0.30)
    img = img * (1 - a(place(c, x0, y0))[..., None]) + a(place(c, x0, y0))[..., None] * BONE * 0.92
    bar_light(img, place(bar, x0, y0), 10, 60, 1.0)
    # Microtipografía técnica: lo que imprimiría el fabricante.
    tx = Image.new("L", (W, H), 0)
    td = ImageDraw.Draw(tx)
    mono = ImageFont.truetype(MONO, 20)
    lab = ImageFont.truetype(FONT, 30)
    td.text((x0, y0 + 400), "command os", font=lab, fill=230)
    td.text((x0, y0 + 442), "CMD-OS  //  R.2026.10  //  NODE 04", font=mono, fill=150)
    for i, line in enumerate(("SYS.INTEGRITY ......... OK", "NET.LINK .............. UP",
                              "DECK.SERIAL ..... C7-0E3-41A")):
        td.text((x0, y0 + 480 + i * 26), line, font=mono, fill=110)
    img += a(tx)[..., None] * BONE * 0.85
    # Código de barras y cruz de registro.
    bc = Image.new("L", (W, H), 0)
    bd = ImageDraw.Draw(bc)
    bx = x0
    for _ in range(46):
        wbar = rnd.choice((2, 2, 3, 5))
        bd.rectangle((bx, y0 + 570, bx + wbar - 1, y0 + 600), fill=255)
        bx += wbar + rnd.choice((2, 3, 4))
    px, py = int(W * 0.12), int(H * 0.18)
    bd.line((px - 22, py, px + 22, py), fill=255, width=1)
    bd.line((px, py - 22, px, py + 22), fill=255, width=1)
    bd.ellipse((px - 10, py - 10, px + 10, py + 10), outline=255, width=1)
    img += a(bc)[..., None] * BONE * 0.35
    # Dos cortes de glitch: franja desplazada con aberración roja/cian.
    for gy0, gh, shift in ((int(H * 0.33), 14, 46), (int(H * 0.71), 8, -70)):
        sl = img[gy0:gy0 + gh].copy()
        img[gy0:gy0 + gh] = np.roll(sl, shift, axis=1)
        img[gy0:gy0 + gh, :, 0] = np.roll(sl[..., 0], shift + 6, axis=1)
        img[gy0:gy0 + gh, :, 2] = np.roll(sl[..., 2], shift - 6, axis=1)
    return finish(img, 33)


# ---------------------------------------------------------------------- void
def void():
    img = np.ones((H, W, 3)) * VOID
    yy = np.linspace(0, 1, H)[:, None]
    img += (yy ** 2.2)[..., None] * (MAROON - VOID) * 0.55  # el suelo se calienta
    m = Image.new("L", (W, H), 0)
    ImageDraw.Draw(m).ellipse((W * 0.18, H * 0.78, W * 0.82, H * 1.25), fill=255)
    img += blur(m, 260)[..., None] * RED * 0.14
    dots = Image.new("L", (W, H), 0)  # matriz de puntos de Command, muy tenue
    d = ImageDraw.Draw(dots)
    for y in range(13, H, 26):
        for x in range(13, W, 26):
            d.ellipse((x - 1, y - 1, x + 1, y + 1), fill=255)
    img += a(dots)[..., None] * (np.array([40, 34, 42], float) - VOID) * 0.55
    return finish(img, 44, grain=0)


FORMATOS = {"16x9": ((2560, 1440), ""), "16x10": ((2560, 1600), "-16x10")}

if __name__ == "__main__":
    OUT.mkdir(parents=True, exist_ok=True)
    for formato in sys.argv[1:] or list(FORMATOS):
        (W, H), sufijo = FORMATOS[formato]
        # Los de escritorio en JPEG de alta calidad (el grano no deja comprimir al PNG: ~4 MB cada uno).
        for name, fn in (("interfaz", interfaz), ("nucleo", nucleo), ("placa", placa)):
            path = OUT / f"command-{name}{sufijo}.jpg"
            fn().save(path, quality=93, subsampling=0, optimize=True)
            print(path, path.stat().st_size)
        # El de bloqueo y GRUB en PNG y sin grano: liso, pesa poco.
        if formato == "16x9":
            path = OUT / "command-void.png"
            void().save(path, optimize=True)
            print(path, path.stat().st_size)
