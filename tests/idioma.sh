#!/usr/bin/env bash
# Command OS — prueba del idioma del sistema sin pantalla: traducciones completas (build/po.sh),
# catálogo instalado, ventanas traducidas (lib/comun.py), command-os-idioma (locale.conf, locales
# generados, rechazo de idiomas que no están en la lista) y textos del tema de GRUB (apply-boot).
#
# Se ejecuta como root en un Arch con el paquete instalado (GitHub Actions, ver
# .github/workflows/escritorio.yml). Cambia el idioma del sistema: solo en un contenedor desechable.
# Sale con 1 si algo falla.
set -uo pipefail

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
for f in /usr/lib/command-os/{comun,greeter,primer-arranque}.py; do
  python3 -m py_compile "${f}" 2>/dev/null && ok "compila $(basename "${f}")" || mal "no compila ${f}"
done
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
# es_ES sin generar (equipos instalados antes): command-os-idioma lo genera.
sed -i -E 's/^(es_ES\.UTF-8 UTF-8)/#\1/' /etc/locale.gen
locale-gen >/dev/null 2>&1
if command-os-idioma es >/dev/null; then ok "command-os-idioma es"; else mal "command-os-idioma es"; fi
locale -a | grep -qix 'es_ES.utf8' && ok "genera es_ES.UTF-8 si falta" || mal "es_ES.UTF-8 sin generar"
[[ "$(lang_de)" == es_ES.UTF-8 ]] && ok "vuelta al castellano" || mal "locale.conf: $(lang_de)"
if [[ -f /boot/grub/themes/command/theme.txt ]]; then
  grep -q 'arranca en %d s' /boot/grub/themes/command/theme.txt && ok "tema de GRUB en castellano" \
    || mal "el tema de GRUB no vuelve al castellano"
fi

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
