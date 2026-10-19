"""Command OS — qué es un archivo descargado y qué hacer con él (lib/abrir-descarga.py). Sin GTK: lo prueba
tests/aplicaciones.sh sin pantalla. docs/notas/escritorio.md § «Instalar aplicaciones»."""
import configparser
import os
import re

# e_machine de la cabecera ELF -> nombre de `uname -m`.
MAQUINAS = {0x03: "i686", 0x28: "armv7l", 0x3E: "x86_64", 0xB7: "aarch64"}
# Lo que puede ejecutar cada procesador además de lo suyo (32 bits, si están sus bibliotecas; si no, el
# programa se cierra al abrirse y abrir-descarga lo dice).
COMPATIBLES = {"x86_64": {"i686"}, "aarch64": {"armv7l"}}
# Trozos del nombre de un paquete que no son el nombre de la aplicación.
RUIDO = {"amd64", "x86", "x64", "i386", "i686", "arm64", "aarch64", "armhf", "noarch", "linux", "current",
         "latest", "stable", "setup", "installer", "deb", "rpm"}


def tipo(ruta):
    """appimage, debian, rpm, repositorio o None, por la extensión (los navegadores la conservan)."""
    nombre = os.path.basename(ruta).lower()
    for ext, t in ((".appimage", "appimage"), (".deb", "debian"), (".rpm", "rpm"), (".flatpakrepo", "repositorio")):
        if nombre.endswith(ext):
            return t
    return None


def busqueda(ruta):
    """El nombre de la aplicación de un paquete, para buscarla en la tienda: «discord-0.0.80.deb» -> «discord»,
    «google-chrome-stable_current_amd64.deb» -> «google chrome»."""
    base = re.sub(r"\.(deb|rpm)$", "", os.path.basename(ruta), flags=re.I)
    palabras = []
    for trozo in re.split(r"[-_.+~\s]+", base):
        # La versión empieza en el primer trozo con cifra que no sea el primero («1password»).
        if palabras and (trozo[0].isdigit() or re.fullmatch(r"v\d.*", trozo, re.I)):
            break
        if trozo.lower() not in RUIDO:
            palabras.append(trozo.lower())
    return " ".join(palabras) or base


def maquina(ruta):
    """El procesador para el que es un ejecutable ELF (como `uname -m`), o None si no se sabe."""
    try:
        with open(ruta, "rb") as f:
            cabecera = f.read(20)
    except OSError:
        return None
    if len(cabecera) < 20 or cabecera[:4] != b"\x7fELF":
        return None
    orden = "little" if cabecera[5] == 1 else "big"
    return MAQUINAS.get(int.from_bytes(cabecera[18:20], orden))


def otro_procesador(ruta, este):
    """El procesador de un ejecutable si este equipo (`uname -m`) no puede ejecutarlo, o None."""
    suyo = maquina(ruta)
    if suyo is None or suyo == este or suyo in COMPATIBLES.get(este, ()):
        return None
    return suyo


def repositorio(ruta):
    """(nombre, título, url) de un .flatpakrepo, o None si no vale. Solo https y con clave GPG (un remoto sin
    firma sería una puerta de entrada), sin claves repetidas ni valores de varias líneas (flatpak lee el
    archivo con GLib, que no los entiende igual: la ventana tiene que enseñar lo que flatpak va a usar). El
    nombre del remoto sale del nombre del archivo, solo con los caracteres que acepta flatpak."""
    datos = configparser.ConfigParser(interpolation=None, strict=True)
    try:
        datos.read(ruta, encoding="utf-8")
        seccion = datos["Flatpak Repo"]
    except (OSError, configparser.Error, KeyError, UnicodeDecodeError):
        return None
    if any("\n" in v for v in seccion.values()):
        return None
    url = seccion.get("Url", "")
    if not url.startswith("https://") or not seccion.get("GPGKey", "").strip():
        return None
    nombre = re.sub(r"[^A-Za-z0-9_-]", "-", re.sub(r"\.flatpakrepo$", "", os.path.basename(ruta), flags=re.I))
    nombre = nombre.strip("-") or "repositorio"
    return nombre, seccion.get("Title", nombre), url
