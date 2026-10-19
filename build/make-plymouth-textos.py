"""Genera los textos del campo de la contraseña del disco en el splash (os/branding/plymouth/command).

En el initramfs, Plymouth dibuja el texto con label-freetype, que pinta la ñ y las tildes como
cuadrados (no tiene un locale UTF-8 ni la fuente de la marca). Estos textos van como imágenes, igual
que el wordmark: JetBrains Mono en minúsculas, como las etiquetas del asistente de primer arranque
(Ash; el fallo, en Red Hot: marca v2). A doble resolución: command.script los reduce al alto de la pantalla.

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
SIZE = 13 * S  # a 1080 px de alto, un punto más que la consola de servicios
ASH = (163, 160, 154, 255)
RED_HOT = (245, 72, 44, 255)


def _(texto):  # marca para build/po.sh: el texto original, en castellano
    return texto


TEXTOS = {
    "texto-clave": (_("contraseña del disco  ·  o la clave de recuperación"), ASH),
    "texto-clave-mala": (_("contraseña incorrecta  ·  vuelve a escribirla"), RED_HOT),
}


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

font = ImageFont.truetype(FONT, SIZE)
# Alto fijo (ascendente + descendente de la fuente): todos los textos quedan a la misma altura.
ascent, descent = font.getmetrics()
fallos = 0
for idioma, tabla in idiomas.items():
    for nombre, (original, color) in TEXTOS.items():
        texto = original if idioma == "es" else tabla.get(original)
        if not texto:
            print(f"{nombre}.{idioma}: falta la traducción de «{original}» en os/po/{idioma}.po", file=sys.stderr)
            fallos = 1
            continue
        w = int(font.getlength(texto)) + 2 * S
        img = Image.new("RGBA", (w, ascent + descent), (0, 0, 0, 0))
        ImageDraw.Draw(img).text((S, 0), texto, font=font, fill=color)
        img.save(OUT / f"{nombre}.{idioma}.png")
        print(f"{nombre}.{idioma}.png", img.size, texto)
sys.exit(fallos)
