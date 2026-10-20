"""Genera los textos del splash (os/branding/plymouth/command): la pantalla de carga de lenguaje.html
(§ 04): la lista de comprobaciones de arranque (título, números, nombres, estados y contador), la
línea de estado de abajo, el consejo, los rótulos de arriba y el campo de la contraseña del disco.

En el initramfs, Plymouth dibuja el texto con label-freetype, que pinta la ñ y las tildes como
cuadrados (no tiene un locale UTF-8 ni la fuente de la marca). Estos textos van como imágenes, igual
que el wordmark, con la letra del concepto: los nombres de las comprobaciones y el consejo en Geist;
las etiquetas (título, números, estados, contador, estado, rótulos y el campo) en JetBrains Mono de
peso 500, en mayúsculas y con 0,14 em de espaciado. A doble resolución: command.script los reduce al
alto de la pantalla.

Una imagen por idioma (<nombre>.<idioma>.png): el castellano es el texto original y el resto sale de
su traducción en os/po/<idioma>.po (docs/idioma.md), así que tests/idioma.sh vigila también estos
textos. Plymouth no sabe el idioma: llega con cada mensaje de las comprobaciones («cmd-diag IDIOMA
ESTADOS») y, para la contraseña, el gancho del initramfs lo lee del parámetro command-os.idioma=
(lib/apply-boot) y command.script elige la imagen por el texto que le llega.

Uso: python build/make-plymouth-textos.py [MONO-MEDIUM.ttf]
     (por defecto, la JetBrains Mono Medium del sistema: ttf-jetbrains-mono-nerd en Arch, o la de Windows)
"""
import ast
import sys
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

REPO = Path(__file__).resolve().parent.parent
OUT = REPO / "os" / "branding" / "plymouth" / "command"
PO = REPO / "os" / "po"
MONOS = [
    "/usr/share/fonts/TTF/JetBrainsMonoNLNerdFont-Medium.ttf",
    "C:/Windows/Fonts/JetBrainsMonoNLNerdFont-Medium.ttf",
    str(Path.home() / "AppData/Local/Microsoft/Windows/Fonts/JetBrainsMonoNLNerdFont-Medium.ttf"),
]
MONO = sys.argv[1] if len(sys.argv) > 1 else next((f for f in MONOS if Path(f).exists()), None)
if not MONO:
    sys.exit("falta JetBrains Mono Medium (ttf-jetbrains-mono-nerd): " + ", ".join(MONOS))
GEIST = str(REPO / "os" / "branding" / "fonts" / "Geist[wght].ttf")  # variable: peso 400 por defecto
S = 2  # doble resolución
SIZE_NOMBRE = 19 * S  # a 1080 px de alto: nombres de las comprobaciones (Geist)
SIZE_CONSEJO = 17 * S  # el consejo (Geist)
SIZE_ETIQUETA = 14 * S  # etiquetas mono en mayúsculas
TRACKING = 0.14  # espaciado de las mayúsculas, en em (lenguaje.html: .mono)
BONE = (237, 235, 230, 255)
ASH = (163, 160, 154, 255)
SMOKE = (133, 130, 124, 255)
IDLE = (110, 108, 104, 255)
RED_HOT = (245, 72, 44, 255)
OK = (61, 220, 132, 255)
NOMBRE, CONSEJO, ETIQUETA = "nombre", "consejo", "etiqueta"


def _(texto):  # marca para build/po.sh: el texto original, en castellano
    return texto


# nombre: (texto, color, estilo). Los de la lista son las comprobaciones de os/lib/diagnostico-arranque,
# en su orden (diag-1 a diag-6); linea-N, lo que se está haciendo mientras la N está en curso.
TEXTOS = {
    "texto-clave": (_("contraseña del disco  ·  o la clave de recuperación"), ASH, ETIQUETA),
    "texto-clave-mala": (_("contraseña incorrecta  ·  vuelve a escribirla"), RED_HOT, ETIQUETA),
    "diag-titulo": (_("comprobaciones de arranque"), SMOKE, ETIQUETA),
    "diag-1": (_("disco del sistema"), BONE, NOMBRE),
    "diag-2": (_("sistemas de archivos"), BONE, NOMBRE),
    "diag-3": (_("dispositivos"), BONE, NOMBRE),
    "diag-4": (_("servicios básicos"), BONE, NOMBRE),
    "diag-5": (_("red"), BONE, NOMBRE),
    "diag-6": (_("inicio de sesión"), BONE, NOMBRE),
    "estado-espera": (_("en espera"), IDLE, ETIQUETA),
    "estado-curso": (_("en curso"), RED_HOT, ETIQUETA),
    "estado-ok": (_("ok"), OK, ETIQUETA),
    "estado-error": (_("error"), RED_HOT, ETIQUETA),
    "linea-0": (_("arrancando"), SMOKE, ETIQUETA),
    "linea-1": (_("comprobando el disco del sistema"), SMOKE, ETIQUETA),
    "linea-2": (_("montando los sistemas de archivos"), SMOKE, ETIQUETA),
    "linea-3": (_("detectando los dispositivos"), SMOKE, ETIQUETA),
    "linea-4": (_("arrancando los servicios básicos"), SMOKE, ETIQUETA),
    "linea-5": (_("arrancando la red"), SMOKE, ETIQUETA),
    "linea-6": (_("sistema listo"), BONE, ETIQUETA),
    "linea-error": (_("una comprobación ha fallado · esc: detalles"), RED_HOT, ETIQUETA),
    "detalles": (_("esc · detalles"), SMOKE, ETIQUETA),
    "consejo": (_("consejo"), RED_HOT, ETIQUETA),
    # Consejos (uno por arranque, al azar): atajos reales de os/dotfiles/labwc/rc.xml.
    "consejo-1": (_("Super + F1 enseña todos los atajos de teclado."), ASH, CONSEJO),
    "consejo-2": (_("Super abre el lanzador de aplicaciones; Super + Intro, la terminal."), ASH, CONSEJO),
    "consejo-3": (_("Super + Escape abre el menú de energía: bloquear, reiniciar o apagar."), ASH, CONSEJO),
    "consejo-4": (_("Super + Ctrl + D crea otro escritorio, hasta cuatro."), ASH, CONSEJO),
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

FUENTES = {
    NOMBRE: ImageFont.truetype(GEIST, SIZE_NOMBRE),
    CONSEJO: ImageFont.truetype(GEIST, SIZE_CONSEJO),
    ETIQUETA: ImageFont.truetype(MONO, SIZE_ETIQUETA),
}


def dibujar(texto, color, estilo, ruta):
    """El texto en una imagen de alto fijo (ascendente + descendente de su fuente): todos los de un
    estilo quedan a la misma altura. Las etiquetas, en mayúsculas y espaciadas."""
    f = FUENTES[estilo]
    ascent, descent = f.getmetrics()
    if estilo == ETIQUETA:
        texto = texto.upper()
        paso = f.size * TRACKING
        w = int(sum(f.getlength(c) for c in texto) + paso * (len(texto) - 1)) + 2 * S
        img = Image.new("RGBA", (w, ascent + descent), (0, 0, 0, 0))
        d, x = ImageDraw.Draw(img), S
        for c in texto:
            d.text((x, 0), c, font=f, fill=color)
            x += f.getlength(c) + paso
    else:
        texto = texto[:1].upper() + texto[1:]  # «Disco del sistema», como los nombres del concepto
        img = Image.new("RGBA", (int(f.getlength(texto)) + 2 * S, ascent + descent), (0, 0, 0, 0))
        ImageDraw.Draw(img).text((S, 0), texto, font=f, fill=color)
    img.save(ruta, optimize=True)
    return img.size


fallos = 0
for idioma, tabla in idiomas.items():
    for nombre, (original, color, estilo) in TEXTOS.items():
        texto = original if idioma == "es" else tabla.get(original)
        if not texto:
            print(f"{nombre}.{idioma}: falta la traducción de «{original}» en os/po/{idioma}.po", file=sys.stderr)
            fallos = 1
            continue
        print(f"{nombre}.{idioma}.png", dibujar(texto, color, estilo, OUT / f"{nombre}.{idioma}.png"), texto)
# Sin idioma: el número de cada comprobación (01…), el contador de hechas (0 / 6 … 6 / 6, en Bone como
# el de lenguaje.html) y el código del sistema junto al wordmark del rótulo de arriba.
for n in range(1, COMPROBACIONES + 1):
    dibujar(f"{n:02d}", IDLE, ETIQUETA, OUT / f"diag-ix-{n}.png")
for n in range(COMPROBACIONES + 1):
    dibujar(f"{n} / {COMPROBACIONES}", BONE, ETIQUETA, OUT / f"diag-cuenta-{n}.png")
dibujar("·  CMD-OS", SMOKE, ETIQUETA, OUT / "codigo.png")
sys.exit(fallos)
