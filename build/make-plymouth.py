"""Genera las imágenes del splash de arranque: la firma de Command, versión corta (BRAND.md § 9.1 y
§ 12.1, ancla 2; docs/DISENO.md § «Movimiento»).

Secuencia (command.script la cronometra; aquí solo se dibuja el símbolo):
- Trazado, 0–900 ms: el contorno del símbolo C en Bone, de 1 px, recorre la forma real del logo
  (el trazado de os/branding/logo/command-mark.svg). Se desvanece de 1050 a 1350 ms.
- Relleno, 800–1350 ms: el símbolo blanco, de izquierda a derecha.
- Barra, 1300–1650 ms: la barra Signal Red se extiende desde la izquierda, con su halo (el único
  halo de la interfaz, BRAND § 7.2).
- Wordmark, 1600–2650 ms: lo destapa command.script con una tapa Void y el cabezal Red Hot.
Salida en os/branding/plymouth/command/:
- simbolo-N.png: un fotograma cada 40 ms del trazado, el relleno y la barra (el último, el símbolo
  completo). Pequeños (el símbolo mide 128 px a 1080 de alto): van dentro del initramfs.
- wordmark.png: el wordmark entero, con su barra.
- px-*.png: píxeles sueltos que command.script estira (medidor, filetes, campo de la contraseña,
  tapa del wordmark y cabezal).
Todo a doble resolución: command.script lo reduce al alto de cada pantalla (nítido en 4K).
Uso: python build/make-plymouth.py
"""
import re
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parent.parent / "os" / "branding"
OUT = ROOT / "plymouth" / "command"
OUT.mkdir(parents=True, exist_ok=True)

# Paleta v2 (tokens.css de command-web).
VOID = (14, 14, 14, 255)
SLATE = (31, 31, 31, 255)
STEEL = (42, 42, 42, 255)
BONE = (237, 235, 230, 255)
SIGNAL_RED = (165, 21, 0, 255)
RED_HOT = (245, 72, 44, 255)

S = 2  # doble resolución
SS = 4  # supermuestreo del trazado (Pillow no suaviza las líneas)
SIM_H = 128 * S  # alto del símbolo (con su barra) a 1080 px de alto
WM_W = 480 * S  # ancho del wordmark a 1080 px de alto
PAD = 12 * S  # margen transparente de los fotogramas del símbolo: cabe el halo de la barra
PASO = 40  # ms entre fotogramas del símbolo (command.script los cambia cada 2 refrescos de 20 ms)
FIN = 1650  # ms: el símbolo ya está completo

# Tiempos de la secuencia, en ms (los mismos en command.script).
TRAZO = (0, 900)
TRAZO_FUERA = (1050, 1350)
RELLENO = (800, 1350)
BARRA = (1300, 1650)


def ease_out(t):  # aprox. cubic-bezier(.16, 1, .3, 1)
    return 1 - (1 - t) ** 4


def ease_in_out(t):  # aprox. cubic-bezier(.65, 0, .35, 1)
    return 4 * t ** 3 if t < 0.5 else 1 - (-2 * t + 2) ** 3 / 2


def fase(ms, tramo):
    """Avance de 0 a 1 dentro del tramo (inicio, fin)."""
    a, b = tramo
    return min(1.0, max(0.0, (ms - a) / (b - a)))


def contorno(svg, escala, ox, oy):
    """Polilínea cerrada del primer trazado del SVG (solo M, L, C y Z absolutos, como el del logo)."""
    d = re.search(r'<path[^>]*\sd="([^"]+)"', svg).group(1)
    tokens = re.findall(r"[MLCZ]|-?\d*\.?\d+", d)
    puntos, cmd, i, actual = [], None, 0, (0.0, 0.0)

    def num():
        nonlocal i
        v = float(tokens[i])
        i += 1
        return v

    while i < len(tokens):
        if tokens[i] in "MLCZ":
            cmd = tokens[i]
            i += 1
            if cmd == "Z":
                continue
        if cmd == "M":
            actual = (num(), num())
            puntos.append(actual)
            cmd = "L"  # pares de más tras M son líneas
        elif cmd == "L":
            actual = (num(), num())
            puntos.append(actual)
        elif cmd == "C":
            p0 = actual
            p1, p2, p3 = (num(), num()), (num(), num()), (num(), num())
            for k in range(1, 25):
                t = k / 24
                u = 1 - t
                puntos.append(tuple(u ** 3 * a + 3 * u * u * t * b + 3 * u * t * t * c + t ** 3 * e
                                    for a, b, c, e in zip(p0, p1, p2, p3)))
            actual = p3
    puntos.append(puntos[0])
    return [((x - ox) * escala, (y - oy) * escala) for x, y in puntos]


def tramo_inicial(puntos, fraccion):
    """Los primeros «fraccion» (0–1) del largo de la polilínea."""
    largos = [((x2 - x1) ** 2 + (y2 - y1) ** 2) ** 0.5 for (x1, y1), (x2, y2) in zip(puntos, puntos[1:])]
    falta = sum(largos) * fraccion
    out = [puntos[0]]
    for (x1, y1), (x2, y2), largo in zip(puntos, puntos[1:], largos):
        if falta >= largo:
            out.append((x2, y2))
            falta -= largo
        else:
            if largo:
                k = falta / largo
                out.append((x1 + (x2 - x1) * k, y1 + (y2 - y1) * k))
            break
    return out


# --- Símbolo ------------------------------------------------------------------------------------
svg = (ROOT / "logo" / "command-mark.svg").read_text(encoding="utf-8")
vx, vy, vw, vh = (float(v) for v in re.search(r'viewBox="([^"]+)"', svg).group(1).split())
barra = re.search(r'<rect[^>]*\sy="([\d.]+)"[^>]*\sheight="([\d.]+)"', svg)
escala = SIM_H / vh
SIM_W = round(vw * escala)
BARRA_Y = round((float(barra.group(1)) - vy) * escala)  # la barra, en la franja inferior del PNG

marca = Image.open(ROOT / "logo" / "command-mark-white.png").convert("RGBA").resize(
    (SIM_W, SIM_H), Image.Resampling.LANCZOS)
cuerpo = marca.copy()
cuerpo.paste((0, 0, 0, 0), (0, BARRA_Y - 2, SIM_W, SIM_H))  # la C sola (la barra va aparte)
barra_img = Image.new("RGBA", marca.size, (0, 0, 0, 0))
barra_img.paste(marca.crop((0, BARRA_Y - 2, SIM_W, SIM_H)), (0, BARRA_Y - 2))
# El PNG blanco trae la barra en su rojo; se pinta Signal Red por si acaso (ancla 1: no se recolorea).
barra_img = Image.composite(Image.new("RGBA", marca.size, SIGNAL_RED), barra_img, barra_img.getchannel("A"))
linea = contorno(svg, escala * SS, vx, vy)
grueso = S * SS  # 1 px a 1080 de alto

for viejo in list(OUT.glob("frame-*.png")) + list(OUT.glob("simbolo-*.png")):
    viejo.unlink()

n = 0
for ms in range(PASO, FIN + PASO, PASO):
    f = Image.new("RGBA", (SIM_W + 2 * PAD, SIM_H + 2 * PAD), (0, 0, 0, 0))
    # Relleno de izquierda a derecha.
    x = round(SIM_W * ease_in_out(fase(ms, RELLENO)))
    if x > 0:
        f.alpha_composite(cuerpo.crop((0, 0, x, SIM_H)), (PAD, PAD))
    # Contorno: se dibuja y, ya relleno el símbolo, se desvanece.
    opacidad = 1 - ease_in_out(fase(ms, TRAZO_FUERA))
    if opacidad > 0:
        grande = Image.new("RGBA", (SIM_W * SS, SIM_H * SS), (0, 0, 0, 0))
        tramo = tramo_inicial(linea, ease_in_out(fase(ms, TRAZO)))
        if len(tramo) > 1:
            ImageDraw.Draw(grande).line(tramo, fill=BONE, width=grueso, joint="curve")
        trazo = grande.resize((SIM_W, SIM_H), Image.Resampling.LANCZOS)
        trazo.putalpha(trazo.getchannel("A").point(lambda a: round(a * opacidad)))
        f.alpha_composite(trazo, (PAD, PAD))
    # Barra con su halo: la barra desenfocada en Red Hot (--cmd-red-glow de tokens.css).
    bx = round(SIM_W * ease_out(fase(ms, BARRA)))
    if bx > 0:
        capa = Image.new("RGBA", f.size, (0, 0, 0, 0))
        capa.alpha_composite(barra_img.crop((0, 0, bx, SIM_H)), (PAD, PAD))
        halo = Image.new("RGBA", f.size, RED_HOT)
        halo.putalpha(capa.getchannel("A").filter(ImageFilter.GaussianBlur(5 * S)).point(lambda a: round(a * 0.6)))
        f.alpha_composite(halo)
        f.alpha_composite(capa)
    f.save(OUT / f"simbolo-{n}.png", optimize=True)
    n += 1
print(n, "fotogramas del símbolo", SIM_W + 2 * PAD, "x", SIM_H + 2 * PAD)

# --- Wordmark (command.script lo destapa de izquierda a derecha) ---------------------------------
word = Image.open(ROOT / "logo" / "command-wordmark-white.png").convert("RGBA")
word = word.resize((WM_W, round(word.height * WM_W / word.width)), Image.Resampling.LANCZOS)
word.save(OUT / "wordmark.png", optimize=True)
print("wordmark", word.size)

# --- Píxeles que command.script estira ------------------------------------------------------------
for nombre, color in {
    "px-red": SIGNAL_RED,     # medidor (relleno) y barra del wordmark
    "px-dim": STEEL,          # pista del medidor y línea del campo de la contraseña
    "px-slate": SLATE,        # filetes entre las comprobaciones
    "px-bone": BONE,          # caracteres tecleados en el campo de la contraseña
    "px-red-hot": RED_HOT,    # cabezal del wordmark, comprobación en curso y cursor del campo
    "px-void": VOID,          # tapa que destapa el wordmark (el fondo es Void liso)
}.items():
    Image.new("RGBA", (1, 1), color).save(OUT / f"{nombre}.png")
