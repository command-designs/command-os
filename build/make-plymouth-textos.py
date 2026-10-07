"""Genera los textos del campo de la contraseña del disco en el splash (os/branding/plymouth/command).

En el initramfs, Plymouth dibuja el texto con label-freetype, que pinta la ñ y las tildes como
cuadrados (no tiene un locale UTF-8 ni la fuente de la marca). Estos textos van como imágenes, igual
que el wordmark: JetBrains Mono en minúsculas, como las etiquetas del asistente de primer arranque
(cian; el fallo, en rojo). A doble resolución: command.script los reduce al alto de la pantalla.

Uso: python build/make-plymouth-textos.py [FUENTE.ttf]
     (por defecto, la JetBrains Mono del sistema: /usr/share/fonts/TTF/JetBrainsMonoNLNerdFont-Regular.ttf)
"""
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

OUT = Path(__file__).resolve().parent.parent / "os" / "branding" / "plymouth" / "command"
FONT = sys.argv[1] if len(sys.argv) > 1 else "/usr/share/fonts/TTF/JetBrainsMonoNLNerdFont-Regular.ttf"
S = 2  # doble resolución
SIZE = 13 * S  # a 1080 px de alto, un punto más que la consola de servicios
CYAN = (91, 191, 196, 255)
RED = (209, 52, 73, 255)

TEXTOS = {
    "texto-clave.png": ("contraseña del disco  ·  o la clave de recuperación", CYAN),
    "texto-clave-mala.png": ("contraseña incorrecta  ·  vuelve a escribirla", RED),
}

font = ImageFont.truetype(FONT, SIZE)
for nombre, (texto, color) in TEXTOS.items():
    # Alto fijo (ascendente + descendente de la fuente): los dos textos quedan a la misma altura.
    ascent, descent = font.getmetrics()
    w = int(font.getlength(texto)) + 2 * S
    img = Image.new("RGBA", (w, ascent + descent), (0, 0, 0, 0))
    ImageDraw.Draw(img).text((S, 0), texto, font=font, fill=color)
    img.save(OUT / nombre)
    print(nombre, img.size)
