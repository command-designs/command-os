#!/usr/bin/env python3
# Command OS — zonas horarias para el asistente de primer arranque (lib/primer-arranque.py), sin GTK:
# la lista (zone.tab de tzdata y UTC, como `command-os-zona-horaria lista`, que es la que valida;
# tests/zona-horaria.sh comprueba que son iguales), nombres de país traducidos (iso-codes, si está),
# búsqueda sin tildes, diferencia con UTC y la zona que sugiere el teclado. Se prueba sin pantalla:
# `python3 zonas.py buscar TEXTO [IDIOMA]`.
import datetime
import functools
import gettext
import json
import os
import re
import subprocess
import sys
import unicodedata
import zoneinfo

ZONEINFO = os.environ.get("COMMAND_OS_ZONEINFO", "/usr/share/zoneinfo")
ADJTIME = os.environ.get("COMMAND_OS_ADJTIME", "/etc/adjtime")
ISO_CODES = "/usr/share/iso-codes/json/iso_3166-1.json"
LOCALES = "/usr/share/locale"


def N_(texto):
    """Marca un texto para traducir sin traducirlo aún."""
    return texto


# Regiones de tzdata, traducidas en os/po/. Las ciudades van tal cual (en inglés, sin «_»): son unas
# 400 y la búsqueda encuentra también el país, que sí sale en el idioma elegido.
REGIONES = {
    "Africa": N_("África"), "America": N_("América"), "Antarctica": N_("Antártida"),
    "Arctic": N_("Ártico"), "Asia": N_("Asia"), "Atlantic": N_("Atlántico"),
    "Australia": N_("Australia"), "Europe": N_("Europa"), "Indian": N_("Índico"),
    "Pacific": N_("Pacífico"),
}

# Teclados de un país: al cambiar a uno, el asistente propone la zona principal del país (si no se
# ha elegido otra a mano ni la actual es ya de ese país: Canarias sigue siendo España). us, latam y
# br no: sus países tienen varias zonas a muchas horas de distancia y adivinar sería peor.
SUGERIDAS = {
    "es": ("ES", "Europe/Madrid"), "pt": ("PT", "Europe/Lisbon"), "gb": ("GB", "Europe/London"),
    "fr": ("FR", "Europe/Paris"), "de": ("DE", "Europe/Berlin"), "it": ("IT", "Europe/Rome"),
}


def palabras(texto):
    """Palabras en minúsculas y sin tildes: «Bogotá» y «bogota» se encuentran igual, y
    «America/New_York» da america, new y york."""
    sin = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode()
    return re.findall(r"[a-z0-9]+", sin.lower())


@functools.cache
def zonas():
    """[(zona, código de país)] de zone.tab, ordenadas, y UTC (sin país) la primera."""
    lista = []
    try:
        with open(os.path.join(ZONEINFO, "zone.tab"), encoding="utf-8") as f:
            for linea in f:
                if linea.startswith("#"):
                    continue
                campos = linea.rstrip("\n").split("\t")
                if len(campos) >= 3:
                    lista.append((campos[2], campos[0]))
    except OSError:
        pass
    return tuple([("UTC", "")] + sorted(set(lista)))


@functools.cache
def paises(idioma=None):
    """{código: nombre del país} en el idioma pedido (iso-codes) o, sin él, en inglés (tzdata)."""
    nombres = {}
    try:
        with open(ISO_CODES, encoding="utf-8") as f:
            for p in json.load(f).get("3166-1", []):
                nombres[p["alpha_2"]] = p.get("common_name") or p["name"]
    except (OSError, ValueError, KeyError):
        try:
            with open(os.path.join(ZONEINFO, "iso3166.tab"), encoding="utf-8") as f:
                for linea in f:
                    if not linea.startswith("#") and "\t" in linea:
                        codigo, nombre = linea.rstrip("\n").split("\t", 1)
                        nombres[codigo] = nombre
        except OSError:
            pass
    if idioma:
        traducir = gettext.translation(
            "iso_3166-1", LOCALES, languages=[idioma.split(".")[0], idioma[:2]], fallback=True
        ).gettext
        nombres = {c: traducir(n) for c, n in nombres.items()}
    return nombres


def ciudad(zona):
    """America/Argentina/Buenos_Aires -> Buenos Aires."""
    return zona.rsplit("/", 1)[-1].replace("_", " ")


def region(zona, _=lambda t: t):
    nombre = REGIONES.get(zona.split("/", 1)[0]) if "/" in zona else None
    return _(nombre) if nombre else ""  # nunca _(""): gettext daría la cabecera del catálogo


class Zona:
    """Una fila de la lista: zona, ciudad, país y el texto en el que se busca."""

    def __init__(self, zona, pais, _=lambda t: t, otros=""):
        """otros: más nombres en los que buscar (el país en inglés, con la ventana en otro idioma)."""
        self.zona = zona
        self.ciudad = "UTC" if zona == "UTC" else ciudad(zona)
        self.pais = pais or _("tiempo universal coordinado")
        textos = (self.ciudad, self.pais, zona, region(zona, _), otros)
        self.palabras = set(palabras(" ".join(textos)))

    def coincide(self, consulta):
        """Cada palabra buscada empieza alguna de la fila («madr», «nueva»…). Por comienzo de
        palabra y no en cualquier parte: «utc» no debe encontrar «Dutch»."""
        return all(any(p.startswith(b) for p in self.palabras) for b in palabras(consulta))


def catalogo(idioma=None, _=lambda t: t):
    """[Zona] con los países en el idioma elegido; también se encuentran por su nombre en inglés,
    y en castellano si la ventana va en otro idioma (quien elige inglés en España busca «España»)."""
    nombres, ingles = paises(idioma), paises()
    castellano = paises("es_ES.UTF-8")
    return [
        Zona(z, nombres.get(c, c), _, f"{ingles.get(c, '')} {castellano.get(c, '')}")
        for z, c in zonas()
    ]


def actual():
    """La zona actual según command-os-zona-horaria (UTC, Europe/Madrid…), o "" si no se sabe."""
    try:
        r = subprocess.run(["command-os-zona-horaria", "actual"], capture_output=True, text=True,
                           timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return r.stdout.strip()


def sugerida(teclado, zona_actual=""):
    """La zona que propone un teclado (es, de(nodeadkeys)…), o None si no propone ninguna o la
    actual ya es de su país."""
    pais, zona = SUGERIDAS.get(teclado.split("(", 1)[0], (None, None))
    if pais and pais == dict(zonas()).get(zona_actual):
        return None
    return zona


def reloj_local():
    """El reloj del equipo va en hora local (dual boot con Windows: /etc/adjtime → LOCAL)."""
    try:
        with open(ADJTIME, encoding="utf-8") as f:
            return f.read().splitlines()[2:3] == ["LOCAL"]
    except OSError:
        return False


def sincronizada():
    """La hora del sistema viene de la red (NTP)."""
    try:
        r = subprocess.run(["timedatectl", "show", "-p", "NTPSynchronized", "--value"],
                           capture_output=True, text=True, timeout=3)
    except (OSError, subprocess.TimeoutExpired):
        return False
    return r.stdout.strip() == "yes"


def diferencia(zona, ahora=None):
    """«UTC», «UTC+2», «UTC−3:30» (con signo menos de verdad)."""
    ahora = ahora or datetime.datetime.now(datetime.timezone.utc)
    try:
        desfase = ahora.astimezone(zoneinfo.ZoneInfo(zona)).utcoffset() or datetime.timedelta()
        minutos = int(desfase.total_seconds() // 60)
    except (zoneinfo.ZoneInfoNotFoundError, ValueError):
        return ""
    if minutos == 0:
        return "UTC"
    signo = "+" if minutos > 0 else "−"
    horas, resto = divmod(abs(minutos), 60)
    return f"UTC{signo}{horas}" + (f":{resto:02d}" if resto else "")


def hora(zona, pared=None, ahora=None):
    """HH:MM en esa zona. Con el reloj del equipo en hora local y sin hora de la red, la hora del
    sistema se calculó con la zona de antes (pared): lo que vale es la hora de pared en esa zona,
    igual para todas."""
    ahora = ahora or datetime.datetime.now(datetime.timezone.utc)
    try:
        return ahora.astimezone(zoneinfo.ZoneInfo(pared or zona)).strftime("%H:%M")
    except (zoneinfo.ZoneInfoNotFoundError, ValueError):
        return ""


if __name__ == "__main__":
    # Para las pruebas: buscar TEXTO [IDIOMA] · sugerida TECLADO [ZONA] · diferencia ZONA · lista
    orden, *args = sys.argv[1:] or ["lista"]
    if orden == "buscar":
        for z in catalogo(args[1] if len(args) > 1 else None):
            if z.coincide(args[0]):
                print(f"{z.zona}\t{z.ciudad}\t{z.pais}")
    elif orden == "sugerida":
        print(sugerida(*args) or "")
    elif orden == "diferencia":
        print(diferencia(args[0]))
    elif orden == "lista":
        for z, _c in zonas():
            print(z)
    else:
        sys.exit(f"zonas.py: orden desconocida: {orden}")
