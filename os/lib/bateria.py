#!/usr/bin/env python3
"""Command OS — batería: los avisos de batería baja y el estado que enseña el panel de la batería (la
barra usa el módulo `battery` de Waybar). No usa GTK: lo prueba tests/barra.sh con una batería simulada
(COMMAND_OS_POWER_SUPPLY). docs/notas/escritorio.md § «Batería».

    bateria.py watch        avisa al 20 % (normal) y al 10 % (urgente) descargándose
"""
import fcntl
import os
import subprocess
import sys
import time

from traducir import traductor

RAIZ = os.environ.get("COMMAND_OS_POWER_SUPPLY", "/sys/class/power_supply")
TAG = "command-os-bateria"
AVISO, CRITICA = 20, 10


def leer(ruta):
    try:
        with open(ruta, encoding="utf-8") as f:
            return f.read().strip()
    except OSError:
        return ""


def numero(ruta):
    try:
        return int(leer(ruta))
    except ValueError:
        return None


def baterias(raiz=RAIZ):
    """Las baterías del equipo. Fuera las de los periféricos (ratón, mando: `scope` = Device) y las de
    una bahía vacía (`present` = 0)."""
    try:
        nombres = sorted(os.listdir(raiz))
    except OSError:
        return []
    return [os.path.join(raiz, n) for n in nombres
            if leer(os.path.join(raiz, n, "type")) == "Battery"
            and leer(os.path.join(raiz, n, "scope")) != "Device"
            and leer(os.path.join(raiz, n, "present")) != "0"]


def enchufado(raiz=RAIZ):
    """True/False si hay un cargador (Mains/USB) que lo diga; None si el equipo no lo cuenta."""
    visto = None
    try:
        nombres = os.listdir(raiz)
    except OSError:
        return None
    for n in nombres:
        if leer(os.path.join(raiz, n, "type")) in ("Mains", "USB", "USB_C", "USB_PD"):
            en = leer(os.path.join(raiz, n, "online"))
            if en == "1":
                return True
            if en == "0":
                visto = False
    return visto


def limite(raiz=RAIZ, bs=None):
    """El límite de carga (charge_control_end_threshold) si el portátil lo permite, o None."""
    for b in baterias(raiz) if bs is None else bs:
        valor = numero(os.path.join(b, "charge_control_end_threshold"))
        if valor is not None:
            return valor
    return None


def estado(raiz=RAIZ):
    """{capacidad, estado, segundos, limite} o None sin batería. estado: cargando, descargando, llena,
    limitada (enchufada y parada en el límite de carga) o enchufada (sin cargar por otro motivo).
    segundos: lo que queda (descargando) o hasta llenarse (cargando), o None si no se sabe."""
    bs = baterias(raiz)
    if not bs:
        return None
    capacidades, estados, medidas = [], [], []
    for b in bs:
        estados.append(leer(os.path.join(b, "status")))
        c = numero(os.path.join(b, "capacity"))
        if c is not None:
            capacidades.append(c)
        # Energía (µWh, µW) o, si el equipo no la da, carga (µAh, µA): las dos sirven para el tiempo.
        for tipo, (n, f, p) in enumerate((("energy_now", "energy_full", "power_now"),
                                          ("charge_now", "charge_full", "current_now"))):
            en, ll = numero(os.path.join(b, n)), numero(os.path.join(b, f))
            if en is not None and ll:
                medidas.append((tipo, en, ll, abs(numero(os.path.join(b, p)) or 0)))
                break
    ahora = lleno = potencia = 0
    # Solo se suman si todas las baterías dan lo mismo (energía o carga): mezclar µWh y µAh no vale.
    if medidas and len(medidas) == len(bs) and len({m[0] for m in medidas}) == 1:
        ahora = sum(m[1] for m in medidas)
        lleno = sum(m[2] for m in medidas)
        potencia = sum(m[3] for m in medidas)
    if lleno:
        capacidad = round(100 * ahora / lleno)
    elif capacidades:
        capacidad = round(sum(capacidades) / len(capacidades))
    else:
        return None
    capacidad = max(0, min(100, capacidad))
    tope = limite(raiz, bs)
    red = enchufado(raiz)
    if "Charging" in estados:
        e = "cargando"
    elif "Discharging" in estados:
        e = "descargando"
    elif all(s == "Full" for s in estados):
        e = "llena"
    elif red is False:
        e = "descargando"
    elif tope is not None and tope < 100 and capacidad >= tope - 5:
        e = "limitada"
    else:
        e = "enchufada"
    segundos = None
    if lleno and potencia:
        if e == "descargando":
            segundos = round(3600 * ahora / potencia)
        elif e == "cargando":
            objetivo = lleno * (tope if tope is not None and tope < 100 else 100) / 100
            segundos = round(3600 * max(0, objetivo - ahora) / potencia)
    if segundos is not None and not 0 < segundos < 48 * 3600:
        segundos = None
    return {"capacidad": capacidad, "estado": e, "segundos": segundos, "limite": tope}


def horas(segundos):
    m = (segundos + 30) // 60
    return f"{m // 60}h{m % 60:02d}"


def resumen(d, tr):
    """«85 % · cargando · 1h20 hasta terminar de cargar»: lo que dice el panel. Cada caso es una frase
    entera (AGENTS.md: nada de textos montados a trozos)."""
    _ = tr
    n, e = d["capacidad"], d["estado"]
    t = horas(d["segundos"]) if d["segundos"] is not None else None
    if e == "cargando":
        texto = _("{n} % · cargando · {t} hasta terminar de cargar") if t else _("{n} % · cargando")
    elif e == "descargando":
        texto = _("{n} % · descargando · quedan {t}") if t else _("{n} % · descargando")
    elif e == "llena":
        texto = _("{n} % · llena")
    elif e == "limitada":
        texto = _("{n} % · enchufada, en el límite de carga")
    else:
        texto = _("{n} % · enchufada, sin cargar")
    return texto.format(n=n, t=t)


def avisar(titulo, texto, urgencia):
    """Sustituye al aviso anterior de la batería (el mismo `synchronous`)."""
    subprocess.run(["notify-send", "--app-name", "command os", "--icon", "battery-caution",
                    "--urgency", urgencia, "--hint", f"string:x-canonical-private-synchronous:{TAG}",
                    titulo, texto], check=False, stderr=subprocess.DEVNULL)


def siguiente_aviso(d, avisado):
    """(aviso que toca o None, umbral ya avisado). Cada umbral avisa una vez por descarga: al enchufar
    se olvida. «cargando» si había un aviso a la vista y se ha enchufado (lo sustituye y se va)."""
    if d is None:
        return None, 100
    if d["estado"] != "descargando":
        return ("cargando" if avisado < 100 else None), 100
    if d["capacidad"] <= CRITICA and avisado > CRITICA:
        return "critica", CRITICA
    if d["capacidad"] <= AVISO and avisado > AVISO:
        return "aviso", AVISO
    return None, avisado


def vigilar():
    # Una sola instancia por sesión, como command-os-updates watch.
    candado = open(os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "command-os-bateria.lock"), "w")
    try:
        fcntl.flock(candado, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return 0
    if not baterias():
        return 0
    _ = traductor()
    avisado = 100
    time.sleep(20)  # que swaync esté listo
    while True:
        d = estado()
        que, avisado = siguiente_aviso(d, avisado)
        if que == "critica":
            avisar(_("batería muy baja"), _("queda un {n} %: enchufa el cargador ya o guarda lo que estés haciendo.")
                   .format(n=d["capacidad"]), "critical")
        elif que == "aviso":
            avisar(_("batería baja"), _("queda un {n} %: enchufa el cargador pronto.").format(n=d["capacidad"]), "normal")
        elif que == "cargando":
            avisar(_("batería"), _("cargando"), "low")
        time.sleep(60)


def main(args):
    orden = args[0] if args else ""
    if orden == "watch":
        return vigilar()
    print((__doc__ or "").strip().split("\n\n")[1], file=sys.stderr)
    return 2


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
