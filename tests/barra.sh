#!/usr/bin/env bash
# Command OS — prueba de la batería y de las aplicaciones fijadas de la barra sin pantalla ni batería:
# el estado de una batería simulada (lib/bateria.py: avisos y panel), cuándo avisa de batería baja, el
# límite de carga (lib/gestionar-bateria sobre un /sys/class/power_supply de mentira) y la parte de la
# barra que generan las aplicaciones fijadas (lib/fijadas.py) y que la ayuda de atajos sale en columnas
# (bin/command-os-keys), lo que hace el clic derecho en el Bluetooth (bin/command-os-bluetooth), la telemetría
# opcional, el lado de la pantalla y la barra flotante (barra.jsonc) y que las órdenes de antes (command-os-estado, command-os-wifi) abren el centro de control. Corre
# en cualquier Linux con python3 (GitHub Actions, ver .github/workflows/pruebas.yml). Sale con 1 si algo falla.
set -uo pipefail

RAIZ=$(cd "$(dirname "$0")/.." && pwd)
LIB="${RAIZ}/os/lib"
T=$(mktemp -d)
trap 'rm -rf "${T}"' EXIT
fallos=0
ok() { echo "  ok   $*"; }
mal() { echo "  MAL  $*"; fallos=$((fallos + 1)); }
# Sin bytecode: un os/lib/__pycache__ entraría en el paquete (PKGBUILD copia os/lib/*).
export PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="${LIB}" XDG_CONFIG_HOME="${T}/config" XDG_RUNTIME_DIR="${T}/run" LANG=es_ES.UTF-8
mkdir -p "${XDG_RUNTIME_DIR}"
PS="${T}/power_supply"
export COMMAND_OS_POWER_SUPPLY="${PS}"

# bateria NOMBRE clave=valor…   una batería (o cargador: type=Mains) simulada
bateria() {
  local d="${PS}/$1" kv
  shift
  rm -rf "${d}"; mkdir -p "${d}"
  for kv in "$@"; do printf '%s\n' "${kv#*=}" > "${d}/${kv%%=*}"; done
}
# estado   lo que lee el panel y los avisos: «capacidad estado» y el resumen del panel, o «ninguna»
estado() {
  python3 -c '
import bateria
from traducir import traductor
d = bateria.estado()
if d is None:
    print("ninguna")
else:
    c, e = d["capacidad"], d["estado"]
    print(f"{c} {e} | {bateria.resumen(d, traductor())}")'
}

echo "==> Estado de la batería (lib/bateria.py: avisos y panel)"
rm -rf "${PS}"; mkdir -p "${PS}"
[[ "$(estado)" == ninguna ]] && ok "sin batería" || mal "sin batería: $(estado)"

bateria hidpp_battery_0 type=Battery scope=Device capacity=40 status=Discharging
[[ "$(estado)" == ninguna ]] && ok "la batería del ratón no cuenta" || mal "batería de un periférico: $(estado)"

bateria BAT0 type=Battery status=Discharging capacity=85 energy_now=42500000 energy_full=50000000 power_now=10000000
bateria AC type=Mains online=0
[[ "$(estado)" == "85 descargando | 85 % · descargando · quedan 4h15" ]] && ok "descargándose, con el tiempo que queda" \
  || mal "descargándose: $(estado)"

bateria BAT0 type=Battery status=Charging capacity=50 energy_now=25000000 energy_full=50000000 power_now=25000000
bateria AC type=Mains online=1
[[ "$(estado)" == "50 cargando | 50 % · cargando · 1h00 hasta terminar de cargar" ]] && ok "cargando, con el tiempo hasta terminar" \
  || mal "cargando: $(estado)"

bateria BAT0 type=Battery status="Not charging" capacity=80 charge_control_end_threshold=80
[[ "$(estado)" == "80 limitada | 80 % · enchufada, en el límite de carga" ]] && ok "enchufada y parada en el límite de carga" \
  || mal "límite: $(estado)"

bateria BAT0 type=Battery status=Full capacity=100
[[ "$(estado)" == "100 llena | 100 % · llena" ]] && ok "llena" || mal "llena: $(estado)"

bateria BAT0 type=Battery status=Discharging capacity=90 energy_now=45000000 energy_full=50000000 power_now=5000000
bateria BAT1 type=Battery status=Unknown capacity=10 energy_now=5000000 energy_full=50000000
[[ "$(estado)" == "50 descargando"* ]] && ok "dos baterías: la carga de las dos juntas" || mal "dos baterías: $(estado)"
bateria BAT1 type=Battery status=Unknown capacity=30 charge_now=1000000 charge_full=2000000
[[ "$(estado)" == "60 descargando | 60 % · descargando" ]] && ok "una en energía y otra en carga: no mezcla unidades" \
  || mal "unidades mezcladas: $(estado)"
rm -rf "${PS}/BAT1"

echo "==> Avisos de batería baja"
salida=$(python3 - <<'PY'
import bateria
avisado, dijo = 100, []
for cap, e in [(25, "descargando"), (20, "descargando"), (19, "descargando"), (10, "descargando"),
               (9, "descargando"), (9, "cargando"), (30, "cargando"), (15, "descargando")]:
    que, avisado = bateria.siguiente_aviso({"capacidad": cap, "estado": e}, avisado)
    dijo.append(que or "-")
print(" ".join(dijo))
PY
)
[[ "${salida}" == "- aviso - critica - cargando - aviso" ]] \
  && ok "20 % normal y 10 % urgente, una vez por descarga; al enchufar se olvida" || mal "avisos: ${salida}"

echo "==> Límite de carga (lib/gestionar-bateria)"
GB="${LIB}/gestionar-bateria"
export COMMAND_OS_LIMITE_CARGA="${T}/etc/limite-carga"
rm -rf "${PS}"; mkdir -p "${PS}"
bateria BAT0 type=Battery status=Charging capacity=60
out=$(bash "${GB}" limite 80 2>&1); rc=$?
[[ ${rc} -eq 3 && "${out}" == *no_soportado* ]] && ok "portátil sin límite de carga: no_soportado" || mal "sin soporte: ${rc} ${out}"

bateria BAT0 type=Battery status=Charging capacity=60 charge_control_end_threshold=100 charge_control_start_threshold=96
lee() { cat "${PS}/BAT0/$1"; }
if bash "${GB}" limite 80 && [[ "$(lee charge_control_end_threshold)" == 80 && "$(lee charge_control_start_threshold)" == 75 \
    && "$(cat "${COMMAND_OS_LIMITE_CARGA}")" == 80 ]]; then
  ok "activar: fin 80, inicio 75 y guardado"
else
  mal "activar: fin $(lee charge_control_end_threshold), inicio $(lee charge_control_start_threshold)"
fi
echo 100 > "${PS}/BAT0/charge_control_end_threshold"
bash "${GB}" aplicar && [[ "$(lee charge_control_end_threshold)" == 80 ]] \
  && ok "aplicar (arranque, vuelta del reposo): lo vuelve a poner" || mal "aplicar: $(lee charge_control_end_threshold)"
if bash "${GB}" limite no && [[ "$(lee charge_control_end_threshold)" == 100 && "$(lee charge_control_start_threshold)" == 0 \
    && ! -e "${COMMAND_OS_LIMITE_CARGA}" ]]; then
  ok "desactivar: hasta el 100 % y sin guardar"
else
  mal "desactivar: fin $(lee charge_control_end_threshold)"
fi
echo 90 > "${PS}/BAT0/charge_control_end_threshold"
bash "${GB}" aplicar && [[ "$(lee charge_control_end_threshold)" == 90 ]] \
  && ok "sin límite guardado, aplicar no toca lo de la BIOS" || mal "aplicar sin límite: $(lee charge_control_end_threshold)"
bateria BAT0 type=Battery capacity=60 charge_control_end_threshold=100 charge_types="Standard [Adaptive] Custom"
bash "${GB}" limite 80 && [[ "$(lee charge_types)" == Custom ]] && ok "Dell: modo Custom para que valgan los umbrales" \
  || mal "Dell: charge_types $(lee charge_types)"
echo 80 > "${PS}/BAT0/charge_control_end_threshold"  # el archivo de mentira no cambia solo de modo
bash "${GB}" aplicar && bash "${GB}" limite no && [[ "$(lee charge_types)" == Adaptive ]] \
  && ok "Dell: al quitarlo vuelve el modo de antes (Adaptive)" || mal "Dell: modo al quitar $(lee charge_types)"
out=$(bash "${GB}" limite 70 2>&1); [[ $? -eq 3 ]] && ok "solo acepta 80 o no" || mal "aceptó otro valor: ${out}"
# Una segunda batería cuyo firmware rechaza el umbral (un directorio: no se puede escribir ni como root).
bateria BAT0 type=Battery capacity=60 charge_control_end_threshold=100
bateria BAT1 type=Battery capacity=60
mkdir "${PS}/BAT1/charge_control_end_threshold"
out=$(bash "${GB}" limite 80 2>&1); rc=$?
[[ ${rc} -eq 3 && "${out}" == *rechazado* && "$(lee charge_control_end_threshold)" == 100 && ! -e "${COMMAND_OS_LIMITE_CARGA}" ]] \
  && ok "si el firmware lo rechaza, todo queda como estaba" || mal "rechazado sin límite previo: ${rc} ${out} $(lee charge_control_end_threshold)"
rm -rf "${PS}/BAT1"; bash "${GB}" limite 80
bateria BAT1 type=Battery capacity=60
mkdir "${PS}/BAT1/charge_control_end_threshold"
out=$(bash "${GB}" limite 80 2>&1); rc=$?
[[ ${rc} -eq 3 && "$(lee charge_control_end_threshold)" == 80 && "$(cat "${COMMAND_OS_LIMITE_CARGA}")" == 80 ]] \
  && ok "con el límite ya puesto, un rechazo no lo quita" || mal "rechazado con límite previo: ${rc} $(lee charge_control_end_threshold)"
rm -rf "${PS}/BAT1"
unset COMMAND_OS_LIMITE_CARGA

echo "==> Aplicaciones fijadas (lib/fijadas.py)"
D="${T}/datos"
export XDG_DATA_HOME="${T}/casa" XDG_DATA_DIRS="${D}"
mkdir -p "${D}/applications" "${D}/icons/Papirus-Dark/16x16/apps" "${D}/icons/hicolor/48x48/apps"
printf '[Desktop Entry]\nType=Application\nName=Firefox\nName[en]=Firefox Web\nIcon=firefox\nExec=firefox\n' \
  > "${D}/applications/firefox.desktop"
printf '[Desktop Entry]\nType=Application\nName=kitty\nIcon=kitty\nExec=kitty\n' > "${D}/applications/kitty.desktop"
printf '[Desktop Entry]\nType=Application\nName=Notas {raras} & <cosas>\nIcon=no-existe\nExec=notas\n' \
  > "${D}/applications/notas.desktop"
touch "${D}/icons/Papirus-Dark/16x16/apps/firefox.svg" "${D}/icons/hicolor/48x48/apps/kitty.png"
echo '/* base */' > "${T}/base.css"
F="${LIB}/fijadas.py"
leer_barra() {  # módulos del grupo, separados por espacios
  python3 -c 'import json, sys; c = json.load(open(sys.argv[1])); print(" ".join(c["group/fijadas"]["modules"]))' \
    "${XDG_RUNTIME_DIR}/command-os/barra/fijadas.jsonc"
}
hoja=$(python3 "${F}" generar "${T}/base.css")
css=$(cat "${hoja}" 2>/dev/null)
if [[ "$(leer_barra)" == "custom/fijada#f0 custom/fijada#f1" \
    && "${css}" == "@import url(\"file://${T}/base.css\");"* \
    && "${css}" == *"#custom-fijada.f0 { background-image: url(\"file://${D}/icons/Papirus-Dark/16x16/apps/firefox.svg\"); }"* \
    && "${css}" == *"#custom-fijada.f1 { background-image: url(\"file://${D}/icons/hicolor/48x48/apps/kitty.png\"); }"* ]]; then
  ok "de serie: navegador y terminal (thunar no está instalado), con sus iconos"
else
  mal "de serie: $(leer_barra) / ${css}"
fi
python3 "${F}" anadir notas.desktop && [[ "$(leer_barra)" == *f2 ]] && ok "fijar una aplicación" || mal "fijar: $(leer_barra)"
tip=$(python3 -c 'import json, sys; print(json.load(open(sys.argv[1]))["custom/fijada#f2"]["tooltip-format"])' \
  "${XDG_RUNTIME_DIR}/command-os/barra/fijadas.jsonc")
[[ "${tip}" == "Notas raras &amp; &lt;cosas&gt; · clic derecho: opciones" ]] && ok "nombre escapado para Waybar" || mal "tooltip: ${tip}"
! python3 "${F}" anadir notas.desktop && ok "no se fija dos veces" || mal "fijada dos veces"
! python3 "${F}" anadir ../../etc/passwd.desktop && ! python3 "${F}" anadir thunar.desktop \
  && ok "rechaza ID raros y aplicaciones que no existen" || mal "aceptó un ID que no vale"
python3 "${F}" mover notas.desktop -1 && python3 "${F}" quitar firefox.desktop
[[ "$(tr '\n' ' ' < "${XDG_CONFIG_HOME}/command-os/fijadas")" == "notas.desktop kitty.desktop " ]] \
  && ok "mover a la izquierda y quitar" || mal "lista: $(cat "${XDG_CONFIG_HOME}/command-os/fijadas")"
rm -f "${D}/applications/kitty.desktop"
python3 "${F}" generar >/dev/null && [[ "$(leer_barra)" == "custom/fijada#f0" ]] \
  && ok "una aplicación desinstalada desaparece de la barra" || mal "desinstalada: $(leer_barra)"
LANG=en_US.UTF-8 python3 -c 'import fijadas; print(fijadas.nombre(fijadas.leer_desktop(fijadas.ruta_desktop("firefox.desktop")), "firefox.desktop"))' \
  | grep -qx 'Firefox Web' && ok "nombre en el idioma de la sesión" || mal "nombre en inglés"
python3 -c 'import fijadas, sys; print(fijadas.ident_de(sys.argv[1]))' "${D}/applications/firefox.desktop" \
  | grep -qx firefox.desktop && ok "la ruta que da el lanzador, como ID" || mal "ruta del lanzador a ID"
mkdir -p "${T}/flatpak"
printf '[Desktop Entry]\nType=Application\nName=Visor\nExec=visor %%U\n' > "${T}/flatpak/org.ej.Visor.desktop"
ln -s "${T}/flatpak/org.ej.Visor.desktop" "${D}/applications/org.ej.Visor.desktop"
python3 -c 'import fijadas, sys; print(fijadas.ident_de(sys.argv[1]))' "${D}/applications/org.ej.Visor.desktop" \
  | grep -qx org.ej.Visor.desktop && ok "un .desktop enlazado (Flatpak) también se fija" || mal "enlace de Flatpak"
salida=$(python3 -c '
import fijadas
print(fijadas.orden_terminal({"Terminal": "true", "Exec": "btop --utf-force %F"}))
print(fijadas.orden_terminal({"Exec": "firefox %u"}))')
[[ "${salida}" == $'[\'kitty\', \'-e\', \'btop\', \'--utf-force\']\nNone' ]] \
  && ok "las de terminal (btop) se abren en kitty, sin los %F" || mal "terminal: ${salida}"
: > "${XDG_CONFIG_HOME}/command-os/fijadas"
python3 "${F}" generar >/dev/null && [[ -z "$(leer_barra)" ]] && ok "lista vacía: grupo vacío" || mal "vacía: $(leer_barra)"
[[ "$(XDG_RUNTIME_DIR=/no/existe bash "${RAIZ}/os/bin/command-os-fijadas" generar "${T}/base.css" 2>/dev/null)" == "${T}/base.css" ]] \
  && ok "si no puede generar, la barra arranca con su hoja de siempre" || mal "sin respaldo de la hoja"
! env -u XDG_RUNTIME_DIR python3 "${F}" generar "${T}/base.css" >/dev/null 2>&1 && [[ ! -e /tmp/command-os/barra/fijadas.jsonc ]] \
  && ok "sin XDG_RUNTIME_DIR no escribe nada (nunca en /tmp)" || mal "generó sin XDG_RUNTIME_DIR"

echo "==> Telemetría de la barra (lib/fijadas.py telemetria)"
telemetria() {  # módulos del grupo y si la hoja vacía su celda
  python3 -c 'import json, sys; c = json.load(open(sys.argv[1])); print(" ".join(c["group/telemetria"]["modules"]))' \
    "${XDG_RUNTIME_DIR}/command-os/barra/fijadas.jsonc"
  grep -c '^#telemetria, window#waybar.left #telemetria, window#waybar.right #telemetria { padding: 0; border: none; }$' "${XDG_RUNTIME_DIR}/command-os/barra/estilo.css"
}
python3 "${F}" generar "${T}/base.css" >/dev/null
[[ "$(python3 "${F}" telemetria)" == no && "$(telemetria | tr '\n' '|')" == "|1|" ]] \
  && ok "oculta de serie: grupo vacío y celda sin filo" || mal "de serie: $(telemetria | tr '\n' '|')"
[[ "$(python3 "${F}" telemetria cambiar)" == si && "$(telemetria | tr '\n' '|')" == "cpu temperature memory|0|" ]] \
  && ok "cambiar: CPU, TMP y MEM a la vista" || mal "cambiar: $(telemetria | tr '\n' '|')"
[[ "$(head -n 1 "${XDG_CONFIG_HOME}/command-os/barra")" == "telemetria=si" && "$(python3 "${F}" telemetria)" == si ]] \
  && ok "el ajuste queda guardado" || mal "ajuste: $(cat "${XDG_CONFIG_HOME}/command-os/barra")"
python3 "${F}" telemetria no >/dev/null && [[ "$(telemetria | tr '\n' '|')" == "|1|" ]] \
  && ok "no: oculta otra vez" || mal "no: $(telemetria | tr '\n' '|')"
! python3 "${F}" telemetria quizas 2>/dev/null && ok "solo acepta si, no o cambiar" || mal "aceptó otro valor"

echo "==> Lado de la pantalla y barra flotante (lib/fijadas.py lado, flotante)"
echo '{}' > "${T}/base.jsonc"
python3 "${F}" generar "${T}/base.css" "${T}/base.jsonc" >/dev/null
barra() {  # lo que fija barra.jsonc encima de la configuración de serie
  python3 - "${XDG_RUNTIME_DIR}/command-os/barra/barra.jsonc" <<'PY'
import json, sys
c = json.load(open(sys.argv[1]))
margen = [c.get(f"margin-{b}") for b in ("top", "right", "bottom", "left")]
print(c["position"], c.get("height"), c.get("width"), c.get("name", "-"), margen if any(margen) else "-",
      repr(c.get("clock", {}).get("format", "-")), c.get("network", {}).get("justify", "-"),
      "include=" + ",".join(c["include"]))
PY
}
INC="include=${T}/base.jsonc,${XDG_RUNTIME_DIR}/command-os/barra/fijadas.jsonc"
[[ "$(python3 "${F}" lado) $(python3 "${F}" flotante)" == "arriba no" && "$(barra)" == "top 36 None - - '-' - ${INC}" ]] \
  && ok "de serie: arriba, fija y con la configuración de serie y las fijadas incluidas" || mal "de serie: $(barra)"
[[ "$(python3 "${F}" lado izquierda)" == izquierda \
    && "$(barra)" == "left 0 36 - - '{0:%H}\\n{0:%M}' center ${INC}" ]] \
  && ok "a la izquierda: 36 de ancho, a lo largo del lado, la hora en dos líneas y las lecturas centradas" \
  || mal "izquierda: $(barra)"
python3 "${F}" generar >/dev/null && [[ "$(barra)" == *" ${INC}" ]] \
  && ok "sin argumentos, parte de la configuración de la última vez" || mal "base olvidada: $(barra)"
[[ "$(python3 "${F}" flotante cambiar)" == si && "$(barra)" == "left 0 36 flotante [8, 8, 8, 8] "* ]] \
  && ok "flotante: 8 px de aire alrededor y la clase para el filo" || mal "flotante: $(barra)"
[[ "$(python3 "${F}" lado abajo)" == abajo && "$(barra)" == "bottom 36 None flotante [8, 8, 8, 8] '-' - ${INC}" ]] \
  && ok "abajo: vuelve a ser horizontal, sin los formatos de un lado" || mal "abajo: $(barra)"
[[ "$(tr '\n' ' ' < "${XDG_CONFIG_HOME}/command-os/barra")" == "telemetria=no lado=abajo flotante=si " ]] \
  && ok "los ajustes quedan guardados juntos" || mal "ajustes: $(cat "${XDG_CONFIG_HOME}/command-os/barra")"
! python3 "${F}" lado centro 2>/dev/null && ! python3 "${F}" lado cambiar 2>/dev/null \
  && ok "lado: solo arriba, abajo, izquierda o derecha" || mal "lado aceptó otro valor"
printf 'telemetria=si\nlado=diagonal\nflotante=quizas\n' > "${XDG_CONFIG_HOME}/command-os/barra"
[[ "$(python3 "${F}" lado) $(python3 "${F}" flotante) $(python3 "${F}" telemetria)" == "arriba no si" ]] \
  && ok "un valor que no vale en el archivo se queda en el de serie" || mal "valores raros: $(python3 "${F}" lado)"
python3 "${F}" telemetria no >/dev/null
salida=$(python3 - "${RAIZ}/os/dotfiles/waybar/config.jsonc" <<'PY'
import json, re, sys
import fijadas
# config.jsonc lleva comentarios // (Waybar los acepta): fuera antes de leerlo.
c = json.loads(re.sub(r"^\s*//.*$", "", open(sys.argv[1], encoding="utf-8").read(), flags=re.M))
for modulo, formatos in fijadas.VERTICAL.items():
    for clave in formatos:
        if clave not in c.get(modulo, {}):
            print(f"{modulo}.{clave}")
PY
)
[[ -z "${salida}" ]] && ok "los formatos de un lado cambian formatos que existen en la barra de serie" \
  || mal "formatos de un lado sin su original: ${salida}"

echo "==> Ayuda de atajos (bin/command-os-keys)"
# wofi de mentira que guarda lo que le llega; la sesión sin locale (LANG=C) es la que descuadraba.
mkdir -p "${T}/bin"
printf '#!/bin/sh\ncat > "%s/atajos"\n' "${T}" > "${T}/bin/wofi"
printf '#!/bin/sh\nexit 1\n' > "${T}/bin/pkill"
printf '#!/bin/sh\necho "$1"\n' > "${T}/bin/command-os-config"
chmod +x "${T}/bin/"*
sed "s|/usr/lib/command-os/textos.sh|${LIB}/textos.sh|" "${RAIZ}/os/bin/command-os-keys" > "${T}/keys"
env -u LC_ALL PATH="${T}/bin:${PATH}" LANG=C bash "${T}/keys"
salida=$(LC_ALL=C.UTF-8 python3 -c '
import sys
filas = open(sys.argv[1], encoding="utf-8").read().splitlines()
mal = [f for f in filas if f[22] != " " or f[23] == " "]
print(len(filas), *mal, sep="\n")' "${T}/atajos")
[[ "${salida}" =~ ^[0-9]+$ && "${salida}" -gt 20 ]] \
  && ok "${salida} atajos con la acción en la misma columna, también con flechas, «·» y «…» sin locale" \
  || mal "atajos descuadrados: ${salida}"

echo "==> Bluetooth (bin/command-os-bluetooth)"
# bluetoothctl y rfkill de mentira: el adaptador encendido o apagado según ${T}/bt, y lo que se pidió en ${T}/bt-ordenes.
printf '#!/bin/sh\necho "bluetoothctl $*" >> "%s/bt-ordenes"\n[ "$1" = show ] && echo "	Powered: $(cat "%s/bt")"\nexit 0\n' "${T}" "${T}" > "${T}/bin/bluetoothctl"
printf '#!/bin/sh\necho "rfkill $*" >> "%s/bt-ordenes"\n' "${T}" > "${T}/bin/rfkill"
chmod +x "${T}/bin/"*
bt() { echo "$1" > "${T}/bt"; : > "${T}/bt-ordenes"; PATH="${T}/bin:${PATH}" sh "${RAIZ}/os/bin/command-os-bluetooth" cambiar; grep -v ' show$' "${T}/bt-ordenes" | tr '\n' ';'; }
[[ "$(bt no)" == "rfkill unblock bluetooth;bluetoothctl power on;" ]] && ok "apagado: quita el bloqueo y lo enciende" \
  || mal "apagado: $(bt no)"
[[ "$(bt yes)" == "bluetoothctl power off;" ]] && ok "encendido: lo apaga" || mal "encendido: $(bt yes)"

echo "==> Órdenes de antes (bin/command-os-estado, bin/command-os-wifi)"
# El panel de estado y el selector de wi-fi son ahora el centro de control (lib/centro.py, probado en
# tests/ajustes.sh por lo que hay detrás): las órdenes viejas solo lo abren.
printf '#!/bin/sh\necho "centro $*" > "%s/centro"\n' "${T}" > "${T}/bin/command-os-centro"
chmod +x "${T}/bin/command-os-centro"
centro() { rm -f "${T}/centro"; PATH="${T}/bin:${PATH}" sh "${RAIZ}/os/bin/$1"; cat "${T}/centro" 2>/dev/null; }
[[ "$(centro command-os-estado)" == "centro " ]] && ok "command-os-estado abre el centro de control" \
  || mal "command-os-estado: $(centro command-os-estado)"
[[ "$(centro command-os-wifi)" == "centro redes" ]] && ok "command-os-wifi abre las redes del centro" \
  || mal "command-os-wifi: $(centro command-os-wifi)"

echo
if (( fallos )); then echo "==> ${fallos} fallo(s)"; exit 1; fi
echo "==> Todo correcto"
