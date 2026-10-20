#!/usr/bin/env bash
# Command OS — prueba del idioma del sistema sin pantalla: traducciones completas (build/po.sh),
# catálogo instalado, ventanas traducidas (lib/comun.py), command-os-idioma (locale.conf, locales
# generados, rechazo de idiomas que no están en la lista) y textos del tema de GRUB (apply-boot).
#
# Se ejecuta como root en un Arch con el paquete instalado (GitHub Actions, ver
# .github/workflows/escritorio.yml). Cambia el idioma del sistema: solo en un contenedor desechable.
# Sale con 1 si algo falla.
# Sin pipefail a propósito: con `orden | grep -q texto`, grep sale al encontrar el texto y la orden de
# la izquierda puede morir por SIGPIPE si aún escribe; con pipefail eso daba fallos intermitentes.
set -u

REPO=$(cd "$(dirname "$0")/.." && pwd)
fallos=0
ok() { echo "  ok   $*"; }
mal() { echo "  MAL  $*"; fallos=$((fallos + 1)); }
lang_de() { sed -nE 's/^LANG=//p' /etc/locale.conf 2>/dev/null | tail -n1; }

echo "==> Traducciones"
if bash "${REPO}/build/po.sh" comprobar; then
  ok "todos los textos traducidos en os/po/*.po"
else
  mal "faltan o sobran traducciones (bash build/po.sh)"
fi
[[ -s /usr/share/locale/en/LC_MESSAGES/command-os.mo ]] && ok "catálogo en inglés instalado" \
  || mal "falta /usr/share/locale/en/LC_MESSAGES/command-os.mo"
for f in /usr/lib/command-os/{comun,greeter,primer-arranque,selector_zona,panel-actualizaciones,panel-cuentas,panel-disco,panel-bateria,bateria,fijadas}.py; do
  python3 -m py_compile "${f}" 2>/dev/null && ok "compila $(basename "${f}")" || mal "no compila ${f}"
done
# Un parámetro llamado _ tapa la función de traducción: _("…") falla y la ventana se queda a medias
# (pasó en la pantalla de inicio de sesión al pulsar «entrar»).
if grep -nE '(def [a-z_]+\(|lambda )[^)]*\b_\b *[,):=]' /usr/lib/command-os/{greeter,primer-arranque,selector_zona,panel-actualizaciones,panel-cuentas,panel-disco,panel-bateria,bateria,fijadas}.py; then
  mal "un parámetro llamado _ tapa la traducción (arriba)"
else
  ok "ningún parámetro tapa _()"
fi
traducido() {  # traducido IDIOMA TEXTO
  PYTHONPATH=/usr/lib/command-os python3 -c \
    'import sys; from comun import traductor; print(traductor(sys.argv[1])(sys.argv[2]))' "$1" "$2"
}
[[ "$(traducido en_US.UTF-8 'crear cuenta')" == "create account" ]] && ok "asistente en inglés" \
  || mal "el asistente no se traduce al inglés"
[[ "$(traducido es_ES.UTF-8 'crear cuenta')" == "crear cuenta" ]] && ok "asistente en castellano" \
  || mal "el asistente en castellano no sale el texto original"
[[ "$(LANG=en_US.UTF-8 TEXTDOMAIN=command-os gettext 'arranca en %d s')" == "starting in %d s" ]] \
  && ok "gettext de los scripts en inglés" || mal "gettext de los scripts no traduce"

echo "==> command-os-idioma"
command-os-idioma lista | grep -qx 'es_ES.UTF-8 español' && command-os-idioma lista | grep -qx 'en_US.UTF-8 English' \
  && ok "lista: castellano e inglés" || mal "lista de idiomas"
printf 'LANG=es_ES.UTF-8\nLC_TIME=C.UTF-8\n' > /etc/locale.conf
for malo in fr 'en;touch /tmp/mal' '../es'; do
  command-os-idioma "${malo}" >/dev/null 2>&1 && mal "acepta el idioma «${malo}»" || ok "rechaza «${malo}»"
done
[[ ! -e /tmp/mal && "$(lang_de)" == es_ES.UTF-8 ]] && ok "un idioma rechazado no toca nada" \
  || mal "un idioma rechazado cambió algo"
if command-os-idioma en >/dev/null; then ok "command-os-idioma en"; else mal "command-os-idioma en"; fi
[[ "$(lang_de)" == en_US.UTF-8 ]] && ok "locale.conf: LANG=en_US.UTF-8" || mal "locale.conf: $(lang_de)"
grep -qx 'LC_TIME=C.UTF-8' /etc/locale.conf && ok "conserva el resto de locale.conf" || mal "se perdió LC_TIME"
[[ $(grep -c '^LANG=' /etc/locale.conf) == 1 ]] && ok "una sola línea LANG" || mal "LANG repetido"
locale -a | grep -qix 'en_US.utf8' && ok "en_US.UTF-8 generado" || mal "en_US.UTF-8 sin generar"
command-os-idioma | grep -q English && ok "dice el idioma actual" || mal "command-os-idioma sin argumentos"
command-os-idioma en_US.UTF-8 | grep -q 'ya es' && ok "repetirlo no rehace nada" || mal "repetir el mismo idioma"
if [[ -f /boot/grub/themes/command/theme.txt ]]; then
  grep -q 'starting in %d s' /boot/grub/themes/command/theme.txt && ok "tema de GRUB en inglés" \
    || mal "el tema de GRUB no está en inglés"
fi
# Idioma de la contraseña del disco en el splash: en la línea del kernel (lib/apply-boot).
if [[ -f /etc/default/grub ]]; then
  grep -qE '^GRUB_CMDLINE_LINUX="(.* )?command-os\.idioma=en"' /etc/default/grub \
    && ok "línea del kernel: command-os.idioma=en" || mal "falta command-os.idioma=en en GRUB_CMDLINE_LINUX"
fi
# es_ES sin generar (equipos instalados antes): command-os-idioma lo genera.
sed -i -E 's/^(es_ES\.UTF-8 UTF-8)/#\1/' /etc/locale.gen
locale-gen >/dev/null 2>&1
if command-os-idioma es >/dev/null; then ok "command-os-idioma es"; else mal "command-os-idioma es"; fi
locale -a | grep -qix 'es_ES.utf8' && ok "genera es_ES.UTF-8 si falta" || mal "es_ES.UTF-8 sin generar"
[[ "$(lang_de)" == es_ES.UTF-8 ]] && ok "vuelta al castellano" || mal "locale.conf: $(lang_de)"
if [[ -f /boot/grub/themes/command/theme.txt ]]; then
  grep -q 'ARRANCA EN %d S' /boot/grub/themes/command/theme.txt && ok "tema de GRUB en castellano" \
    || mal "el tema de GRUB no vuelve al castellano"
fi
if [[ -f /etc/default/grub ]]; then
  [[ "$(grep -c 'command-os\.idioma=' /etc/default/grub)" == 1 ]] && grep -q 'command-os\.idioma=es' /etc/default/grub \
    && ok "línea del kernel: vuelve a command-os.idioma=es (una sola vez)" || mal "command-os.idioma= al volver al castellano"
fi

echo "==> Splash: textos de la contraseña del disco y de las comprobaciones de arranque"
# Cada imagen que carga command.script existe, en cada idioma (build/make-plymouth-textos.py).
script="${REPO}/os/branding/plymouth/command/command.script"
faltan=""
for img in $(grep -oE '"[a-z0-9][a-z0-9.-]*\.png"' "${script}" | tr -d '"'); do
  [[ -f "${REPO}/os/branding/plymouth/command/${img}" ]] || faltan+=" ${img}"
done
[[ -z "${faltan}" ]] && ok "el splash tiene todas sus imágenes" || mal "faltan imágenes del splash:${faltan}"
for idioma in es $(basename -s .po "${REPO}"/os/po/*.po); do
  for img in texto-clave texto-clave-mala diag-titulo diag-{1..6} estado-{espera,curso,ok,error}; do
    [[ -f "${REPO}/os/branding/plymouth/command/${img}.${idioma}.png" ]] \
      || mal "falta ${img}.${idioma}.png (python build/make-plymouth-textos.py)"
  done
done
# Lo que manda el gancho en cada idioma lo reconoce command.script (si no, saldría como texto plano).
for idioma in es en; do
  textos=$(bash -c '. "$1"; textos_cifrado "$2"; printf "%s\n%s\n" "${TEXTO_PEDIR}" "${TEXTO_MALA}"' _ \
    "${REPO}/os/initcpio/hooks/command-os-cifrado" "${idioma}")
  claves=$(grep -oE 'contains\(prompt, "[^"]+"\)' "${script}" | sed -E 's/.*"([^"]+)".*/\1/')
  reconocidos=0
  while IFS= read -r texto; do
    while IFS= read -r clave; do [[ "${texto}" == *"${clave}"* ]] && { reconocidos=$((reconocidos + 1)); break; }; done <<< "${claves}"
  done <<< "${textos}"
  [[ "${reconocidos}" == 2 ]] && ok "splash: reconoce los textos del gancho en ${idioma}" \
    || mal "splash: command.script no reconoce los textos del gancho en ${idioma}"
done

echo "==> Textos del escritorio (barra, menús, bloqueo, scripts)"
T=$(mktemp -d)
trap 'rm -rf "${T}"' EXIT
export XDG_RUNTIME_DIR="${T}/run" XDG_CONFIG_HOME="${T}/config" HOME="${T}/home"
mkdir -p "${XDG_RUNTIME_DIR}" "${XDG_CONFIG_HOME}" "${HOME}"
chmod 700 "${XDG_RUNTIME_DIR}"
json_ok() { python3 -c 'import json, re, sys; json.loads(re.sub(r"(?m)^\s*//.*$", "", open(sys.argv[1]).read()))' "$1"; }
# Waybar: la configuración de serie sale traducida y sigue siendo JSON.
cfg=$(LANG=en_US.UTF-8 command-os-config waybar/config.jsonc)
[[ "${cfg}" == "${XDG_RUNTIME_DIR}"/* ]] && grep -q 'no network' "${cfg}" && grep -q 'click: connections' "${cfg}" \
  && ! grep -q '{{' "${cfg}" && ok "waybar en inglés" || mal "la configuración de Waybar no sale en inglés"
json_ok "${cfg}" && ok "waybar traducida sigue siendo JSON" || mal "waybar traducida no es JSON válido"
cfg=$(LANG=es_ES.UTF-8 command-os-config waybar/config.jsonc)
grep -q 'sin red' "${cfg}" && ! grep -q '{{' "${cfg}" && json_ok "${cfg}" && ok "waybar en castellano" \
  || mal "la configuración de Waybar en castellano"
mkdir -p "${XDG_CONFIG_HOME}/waybar" && echo '{ "propia": true }' > "${XDG_CONFIG_HOME}/waybar/config.jsonc"
[[ "$(command-os-config waybar/config.jsonc)" == "${XDG_CONFIG_HOME}/waybar/config.jsonc" ]] \
  && ok "la configuración propia de la cuenta manda" || mal "se ignoró la configuración propia de Waybar"
rm -rf "${XDG_CONFIG_HOME}/waybar"
# hyprlock (normal y de emergencia): sin llaves en ningún idioma.
for f in hyprlock hyprlock-emergencia; do
  src=/usr/share/command-os/config/hypr/${f}.conf
  [[ -e "${src}" ]] || src=/etc/xdg/hypr/${f}.conf
  LANG=en_US.UTF-8 /usr/lib/command-os/traducir.py plantilla "${src}" | grep -q 'session locked' \
    && ok "${f} en inglés" || mal "${f} no sale en inglés"
  /usr/lib/command-os/traducir.py plantilla "${src}" | grep -q '{{' && mal "${f} deja llaves" || ok "${f} sin llaves"
done
# Menús de labwc: etiquetas traducidas y XML válido.
LANG=en_US.UTF-8 /usr/lib/command-os/traducir.py etiquetas /usr/share/command-os/config/labwc/menu.xml > "${T}/menu-en.xml"
grep -q 'label="keyboard shortcuts"' "${T}/menu-en.xml" && grep -q 'label="applications"' "${T}/menu-en.xml" \
  && ok "menú de labwc en inglés" || mal "el menú de labwc no sale en inglés"
python3 -c 'import sys, xml.dom.minidom as m; m.parse(sys.argv[1])' "${T}/menu-en.xml" \
  && ok "menú traducido: XML válido" || mal "menú traducido: XML roto"
[[ "$(grep -c 'label=' "${T}/menu-en.xml")" == "$(grep -c 'label=' /usr/share/command-os/config/labwc/menu.xml)" ]] \
  && ok "menú traducido: las mismas etiquetas" || mal "menú traducido: cambió el número de etiquetas"
# lib/menus-labwc: lo que labwc lee de verdad (primera carpeta de XDG_CONFIG_DIRS), por idioma.
dir=$(LANG=en_US.UTF-8 /usr/lib/command-os/menus-labwc)
[[ "${dir}" == "${XDG_RUNTIME_DIR}/command-os/xdg" ]] && grep -q 'label="keyboard shortcuts"' "${dir}/labwc/menu.xml" \
  && ok "menus-labwc: menú en inglés" || mal "menus-labwc no deja el menú en inglés"
dir=$(LANG=es_ES.UTF-8 /usr/lib/command-os/menus-labwc)
grep -q 'label="atajos de teclado"' "${dir}/labwc/menu.xml" && ok "menus-labwc: el menú sigue al idioma" \
  || mal "menus-labwc no vuelve al castellano"
[[ ! -e /etc/xdg/labwc/menu.xml ]] && ok "no hay menú en /etc/xdg/labwc (labwc se quedaría con ese)" \
  || mal "sobra /etc/xdg/labwc/menu.xml: taparía el traducido"
XDG_RUNTIME_DIR=/no/existe /usr/lib/command-os/menus-labwc >/dev/null 2>&1 \
  && mal "menus-labwc sin carpeta de ejecución debe fallar" || ok "menus-labwc falla sin carpeta de ejecución"
# Scripts de shell: t y tn (singular y plural).
tt() { LANG=$1 bash -c '. /usr/lib/command-os/textos.sh; "$@"' _ "${@:2}"; }
[[ "$(tt en_US.UTF-8 t 'hace %d min' 5)" == '5 min ago' ]] && ok "t con datos" || mal "t con datos"
[[ "$(tt en_US.UTF-8 tn 'y %d paquete más' 'y %d paquetes más' 1 1)" == 'and 1 more package' ]] \
  && [[ "$(tt en_US.UTF-8 tn 'y %d paquete más' 'y %d paquetes más' 3 3)" == 'and 3 more packages' ]] \
  && ok "tn: singular y plural en inglés" || mal "tn en inglés"
[[ "$(tt es_ES.UTF-8 tn 'y %d paquete más' 'y %d paquetes más' 3 3)" == 'y 3 paquetes más' ]] \
  && [[ "$(tt es_ES.UTF-8 t 'hace %d min' 5)" == 'hace 5 min' ]] && ok "t y tn en castellano" || mal "t y tn en castellano"
# Órdenes de terminal: mensajes en el idioma de la sesión (no en el que se elige).
[[ "$(LANG=en_US.UTF-8 command-os-idioma fr 2>&1)" == *'language not available'* ]] \
  && [[ "$(LANG=es_ES.UTF-8 command-os-idioma fr 2>&1)" == *'idioma no disponible'* ]] \
  && ok "command-os-idioma: errores en el idioma de la sesión" || mal "command-os-idioma: errores sin traducir"
LANG=en_US.UTF-8 command-os-idioma | grep -q '^language: ' && LANG=es_ES.UTF-8 command-os-idioma | grep -q '^idioma: ' \
  && ok "command-os-idioma: estado en los dos idiomas" || mal "command-os-idioma: estado"
LANG=en_US.UTF-8 command-os-login | grep -q '^at power on: ' && LANG=es_ES.UTF-8 command-os-login | grep -q '^al encender: ' \
  && ok "command-os-login: modo actual en los dos idiomas" || mal "command-os-login: modo actual"
[[ "$(tt en_US.UTF-8 t 'SI')" == YES && "$(tt es_ES.UTF-8 t 'SI')" == SI ]] \
  && ok "palabra de confirmación de command-os-rollback por idioma" || mal "palabra de confirmación"
if ! mountpoint -q /.snapshots; then
  [[ "$(LANG=en_US.UTF-8 command-os-rollback 2>&1)" == *'no snapshots: the root is not btrfs'* ]] \
    && [[ "$(LANG=es_ES.UTF-8 command-os-rollback 2>&1)" == *'no hay instantáneas'* ]] \
    && ok "command-os-rollback: error en los dos idiomas" || mal "command-os-rollback: error sin traducir"
fi
# El aviso de la barra, en inglés.
export COMMAND_OS_UPDATES_STATE="${T}/updates" COMMAND_OS_PACMAN_LOCAL="${T}/local"
mkdir -p "${COMMAND_OS_PACMAN_LOCAL}"; touch -d '1 hour ago' "${COMMAND_OS_PACMAN_LOCAL}"
printf '%s\ncommand-os 1-1 -> 2-1\nmesa 1-1 -> 2-1\n' "$(date +%s)" > "${COMMAND_OS_UPDATES_STATE}"
LANG=en_US.UTF-8 command-os-updates status | grep -q 'and 1 more package' \
  && LANG=en_US.UTF-8 command-os-updates status | grep -q 'click: review and update' \
  && ok "aviso de actualizaciones en inglés" || mal "el aviso de actualizaciones no sale en inglés"
unset COMMAND_OS_UPDATES_STATE COMMAND_OS_PACMAN_LOCAL XDG_RUNTIME_DIR XDG_CONFIG_HOME

echo "==> Entorno de las ventanas (lib/entorno-grafico)"
printf 'LANG="en_US.UTF-8"\nLC_TIME=C.UTF-8\n' > /etc/locale.conf
[[ "$(env -u LANG bash -c 'source /usr/lib/command-os/entorno-grafico; echo "${LANG}|${LC_TIME}"')" \
  == 'en_US.UTF-8|C.UTF-8' ]] && ok "lee LANG y LC_* de locale.conf" || mal "entorno-grafico no lee el idioma"
printf "LANG='en_US.UTF-8'\n" > /etc/locale.conf
[[ "$(env -u LANG bash -c 'source /usr/lib/command-os/entorno-grafico; echo "${LANG}"')" == en_US.UTF-8 ]] \
  && ok "comillas simples en locale.conf" || mal "entorno-grafico con comillas simples"
command-os-idioma | grep -q English && ok "command-os-idioma con comillas simples" || mal "command-os-idioma con comillas"
rm /etc/locale.conf
command-os-idioma | grep -q 'sin definir' && ok "sin locale.conf: «sin definir»" || mal "command-os-idioma sin locale.conf"
printf 'LANG=es_ES.UTF-8\n' > /etc/locale.conf

echo
if (( fallos )); then echo "==> ${fallos} fallo(s)"; exit 1; fi
echo "==> todo bien"
