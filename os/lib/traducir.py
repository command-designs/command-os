#!/usr/bin/env python3
"""Command OS — traducciones para Python y para los archivos de configuración estáticos
(docs/idioma.md). No usa GTK: lo cargan también scripts que arrancan antes del escritorio.

    traducir.py plantilla ARCHIVO   el archivo con cada {{texto}} traducido (Waybar, hyprlock)
    traducir.py etiquetas ARCHIVO   el XML con cada label="texto" traducido (menús de labwc)

El texto original es el castellano: sin catálogo para el idioma (o sin el texto), se deja tal cual.
"""
import gettext
import re
import sys
from xml.sax.saxutils import escape, unescape

DOMINIO = "command-os"
LOCALES = "/usr/share/locale"

# {{texto}}: lo traducible dentro de un archivo que no puede llamar a gettext. Sin llaves dentro, para
# no confundirse con los {campos} de Waybar. build/po.sh usa esta misma expresión para extraerlos.
MARCA = re.compile(r"\{\{([^{}]+)\}\}")
ETIQUETA = re.compile(r'(\blabel=")([^"]*)(")')


def traductor(idioma=None):
    """La función de traducción del idioma pedido (es_ES.UTF-8, en_US.UTF-8…) o, sin él, del
    entorno (LANG, que pone entorno-grafico desde /etc/locale.conf)."""
    idiomas = [idioma.split(".")[0]] if idioma else None
    return gettext.translation(DOMINIO, LOCALES, languages=idiomas, fallback=True).gettext


def plantilla(texto, _=None):
    _ = _ or traductor()
    return MARCA.sub(lambda m: _(m.group(1)), texto)


def etiquetas(xml, _=None):
    """Traduce los label="…" de un menú de labwc. El original está escapado para XML (&amp;…)."""
    _ = _ or traductor()
    return ETIQUETA.sub(lambda m: m.group(1) + escape(_(unescape(m.group(2))), {'"': "&quot;"}) + m.group(3), xml)


def main(args):
    if len(args) != 2 or args[0] not in ("plantilla", "etiquetas"):
        print((__doc__ or "").strip().split("\n\n")[1], file=sys.stderr)
        return 2
    with open(args[1], encoding="utf-8") as f:
        texto = f.read()
    sys.stdout.write((plantilla if args[0] == "plantilla" else etiquetas)(texto))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
