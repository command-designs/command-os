"""Genera los textos del splash (os/branding/plymouth/command): el campo de la contraseña del disco y
la lista de comprobaciones de arranque (nombres, estados, título, números y contador).

En el initramfs, Plymouth dibuja el texto con label-freetype, que pinta la ñ y las tildes como
cuadrados (no tiene un locale UTF-8 ni la fuente de la marca). Estos textos van como imágenes, igual
que el wordmark: JetBrains Mono en minúsculas, como las etiquetas del asistente de primer arranque
(Ash; el fallo, en Red Hot: marca v2); los estados y el título, en mayúsculas pequeñas y espaciadas,
como .diag__state y .eyebrow de components.css. A doble resolución: command.script los reduce al
alto de la pantalla.

Una imagen por idioma (texto-clave.<idioma>.png): el castellano es el texto original y el resto sale
de su traducción en os/po/<idioma>.po (docs/idioma.md), así que tests/idioma.sh vigila también estos
textos. Plymouth no sabe el idioma: el gancho del initramfs lo lee del parámetro command-os.idioma=
(lib/apply-boot) y command.script elige la imagen por el texto que le llega.

Uso: python build/make-plymouth-textos.py [FUENTE.ttf]
     (por defecto, la JetBrains Mono del sistema: /usr/share/fonts/TTF/JetBrainsMonoNLNerdFont-Regular.ttf)
"""
import ast
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "os" / "branding" / "plymouth" / "command"
PO = REPO / "os" / "po"
FONT = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/fonts/TTF/JetBrainsMonoNLNerdFont-Regular.ttf"
S = 2  # doble resolución
SIZE = 13 * S  # a 1080 px de alto: textos del campo y nombres de las comprobaciones
SIZE_ETIQUETA = 12 * S  # estados, título y contador (como .diag__state y .eyebrow: mono, mayúsculas)
TRACKING = 0.08  # espaciado de las mayúsculas, en em (--tracking-mono de tokens.css)
BONE = (237, 235, 230, 255)
ASH = (163, 160, 154, 255)
SMOKE = (133, 130, 124, 255)
RED_HOT = (245, 72, 44, 255)
OK = (61, 220, 132, 255)


def _(texto):  # marca para build/po.sh: el texto original, en castellano
    return texto


# nombre: (texto, color, mayúsculas). Los de la lista de diagnóstico son las comprobaciones de
# os/lib/diagnostico-arranque, en su orden (diag-1 a diag-6).
TEXTOS = {
    "texto-clave": (_("contraseña del disco  ·  o la clave de recuperación"), ASH, False),
    "texto-clave-mala": (_("contraseña incorrecta  ·  vuelve a escribirla"), RED_HOT, False),
    "diag-titulo": (_("comprobaciones de arranque"), SMOKE, True),
    "diag-1": (_("disco del sistema"), BONE, False),
    "diag-2": (_("sistemas de archivos"), BONE, False),
    "diag-3": (_("dispositivos"), BONE, False),
    "diag-4": (_("servicios básicos"), BONE, False),
    "diag-5": (_("red"), BONE, False),
    "diag-6": (_("inicio de sesión"), BONE, False),
    "estado-espera": (_("en espera"), SMOKE, True),
    "estado-curso": (_("en curso"), RED_HOT, True),
    "estado-ok": (_("ok"), OK, True),
    "estado-error": (_("error"), RED_HOT, True),
}
COMPROBACIONES = 6  # diag-1 … diag-6


def catalogo(po):
    """{original: traducción} de un .po (solo textos simples, sin plurales ni «fuzzy»)."""
    tabla, campo, actual, fuzzy = {}, None, {"msgid": "", "msgstr": ""}, False

    def guardar():
        if actual["msgid"] and actual["msgstr"] and not fuzzy:
            tabla[actual["msgid"]] = actual["msgstr"]

    for linea in po.read_text(encoding="utf-8").splitlines() + [""]:
        linea = linea.strip()
        if not linea:
            guardar()
            campo, actual, fuzzy = None, {"msgid": "", "msgstr": ""}, False
        elif linea.startswith("#,") and "fuzzy" in linea:
            fuzzy = True
        elif linea.startswith(("msgid ", "msgstr ")):
            campo, valor = linea.split(" ", 1)
            actual[campo] = ast.literal_eval(valor)
        elif linea.startswith('"') and campo in actual:
            actual[campo] += ast.literal_eval(linea)
        elif not linea.startswith("#"):
            campo = None  # msgid_plural, msgstr[n]…: no se usan aquí
    return tabla


idiomas = {"es": {}}
for po in sorted(PO.glob("*.po")):
    idiomas[po.stem] = catalogo(po)

fuente = ImageFont.truetype(FONT, SIZE)
fuente_etiqueta = ImageFont.truetype(FONT, SIZE_ETIQUETA)


def dibujar(texto, color, mayusculas, ruta):
    """El texto en una imagen de alto fijo (ascendente + descendente de su fuente): todos los de un
    tamaño quedan a la misma altura. Las mayúsculas van más pequeñas y espaciadas."""
    f = fuente_etiqueta if mayusculas else fuente
    ascent, descent = f.getmetrics()
    if mayusculas:
        texto = texto.upper()
        paso = f.size * TRACKING
        w = int(sum(f.getlength(c) for c in texto) + paso * (len(texto) - 1)) + 2 * S
        img = Image.new("RGBA", (w, ascent + descent), (0, 0, 0, 0))
        d, x = ImageDraw.Draw(img), S
        for c in texto:
            d.text((x, 0), c, font=f, fill=color)
            x += f.getlength(c) + paso
    else:
        img = Image.new("RGBA", (int(f.getlength(texto)) + 2 * S, ascent + descent), (0, 0, 0, 0))
        ImageDraw.Draw(img).text((S, 0), texto, font=f, fill=color)
    img.save(ruta, optimize=True)
    return img.size


fallos = 0
for idioma, tabla in idiomas.items():
    for nombre, (original, color, mayusculas) in TEXTOS.items():
        texto = original if idioma == "es" else tabla.get(original)
        if not texto:
            print(f"{nombre}.{idioma}: falta la traducción de «{original}» en os/po/{idioma}.po", file=sys.stderr)
            fallos = 1
            continue
        print(f"{nombre}.{idioma}.png", dibujar(texto, color, mayusculas, OUT / f"{nombre}.{idioma}.png"), texto)
# Sin idioma: el número de cada comprobación (01…) y el contador de hechas (0 / 6 … 6 / 6).
for n in range(1, COMPROBACIONES + 1):
    dibujar(f"{n:02d}", SMOKE, True, OUT / f"diag-ix-{n}.png")
for n in range(COMPROBACIONES + 1):
    dibujar(f"{n} / {COMPROBACIONES}", SMOKE, True, OUT / f"diag-cuenta-{n}.png")
sys.exit(fallos)
