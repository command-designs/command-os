#!/usr/bin/env bash
# Command OS — prueba del aviso de actualizaciones sin red ni pantalla: lo que enseña la barra
# (command-os-updates status) según lo que dejó la comprobación, la propia comprobación
# (lib/check-updates, con un `checkupdates` y un `busctl` de mentira) y las unidades de systemd.
#
# Se ejecuta en un Arch con el paquete instalado (GitHub Actions, ver .github/workflows/escritorio.yml).
# No toca el sistema: todo va a una carpeta temporal. Sale con 1 si algo falla.
set -uo pipefail

fallos=0
ok() { echo "  ok   $*"; }
mal() { echo "  MAL  $*"; fallos=$((fallos + 1)); }

T=$(mktemp -d)
trap 'rm -rf "${T}"' EXIT
export COMMAND_OS_UPDATES_STATE="${T}/updates" COMMAND_OS_PACMAN_LOCAL="${T}/local" HOME="${T}/home"
mkdir -p "${COMMAND_OS_PACMAN_LOCAL}" "${HOME}"
touch -d '1 hour ago' "${COMMAND_OS_PACMAN_LOCAL}"
ahora=$(date +%s)

estado() { command-os-updates status; }
clase() { estado | sed -E 's/.*"class": "([a-z]*)".*/\1/'; }

echo "==> Lo que enseña la barra"
rm -f "${COMMAND_OS_UPDATES_STATE}"
[[ "$(clase)" == ninguna ]] && ok "sin comprobación: nada" || mal "sin comprobación debe estar oculto"
echo "${ahora}" > "${COMMAND_OS_UPDATES_STATE}"
[[ "$(clase)" == ninguna ]] && ok "comprobación sin novedades: nada" || mal "sin novedades debe estar oculto"
estado | grep -q '"text": ""' && ok "texto vacío (Waybar oculta el módulo)" || mal "el texto debe ir vacío"

printf '%s\nlinux 7.2.7.arch1-1 -> 7.2.8.arch1-2\nmesa 26.1.0-1 -> 26.1.1-1\n' "${ahora}" > "${COMMAND_OS_UPDATES_STATE}"
[[ "$(clase)" == paquetes ]] && ok "paquetes de Arch: clase «paquetes»" || mal "clase con paquetes sueltos"
estado | grep -q 'upd</span> 2"' && ok "cuenta 2 paquetes" || mal "debe contar 2 paquetes"
estado | grep -q 'mesa 26.1.0-1 → 26.1.1-1' && ok "el tooltip lista los paquetes" || mal "tooltip sin la lista"

printf '%s\ncommand-os 2026.10.07.0803-1 -> 2026.10.08.1200-1\nlinux 7.2.7.arch1-1 -> 7.2.8.arch1-2\n' "${ahora}" > "${COMMAND_OS_UPDATES_STATE}"
[[ "$(clase)" == nueva ]] && ok "versión nueva de command-os: clase «nueva» (ámbar)" || mal "clase con command-os nuevo"
estado | grep -q 'command-os 2026.10.07.0803 → 2026.10.08.1200' && ok "el tooltip da las dos versiones" || mal "tooltip sin versiones"
estado | grep -q 'upd</span> 2"' && ok "cuenta command-os y el resto" || mal "debe contar 2"
[[ "$(estado | wc -l)" == 1 ]] && ok "una sola línea (Waybar lee una por vez)" || mal "la salida debe ser una línea"

printf '%s\nlinux 7.2.7.arch1-1 -> 7.2.8.arch1-2\n' "$((ahora - 3600))" > "${COMMAND_OS_UPDATES_STATE}"
touch -d '10 minutes ago' "${COMMAND_OS_PACMAN_LOCAL}"
[[ "$(clase)" == ninguna ]] && ok "comprobación anterior a un cambio de pacman: oculta" || mal "una comprobación vieja no debe enseñarse"

echo 'basura' > "${COMMAND_OS_UPDATES_STATE}"
[[ "$(clase)" == ninguna ]] && ok "archivo corrupto: oculto" || mal "un archivo corrupto no debe romper la barra"
command-os-updates nada >/dev/null 2>&1 && mal "acepta una orden desconocida" || ok "rechaza una orden desconocida"

echo "==> La comprobación (lib/check-updates)"
CHECK=/usr/lib/command-os/check-updates
FALSO="${T}/falso"
mkdir -p "${FALSO}"
export COMMAND_OS_UPDATES_DIR="${T}/estado" CHECKUPDATES_DB="${T}/db"
cat > "${FALSO}/checkupdates" <<'FAKE'
#!/bin/sh
cat "${FALSO_SALIDA}" 2>/dev/null
exit "${FALSO_CODIGO:-0}"
FAKE
chmod +x "${FALSO}/checkupdates"
export FALSO_SALIDA="${T}/salida"

printf 'linux 7.2.7.arch1-1 -> 7.2.8.arch1-2\n' > "${FALSO_SALIDA}"
PATH="${FALSO}:${PATH}" FALSO_CODIGO=0 "${CHECK}" manual && ok "con actualizaciones: termina bien" || mal "con actualizaciones debe salir 0"
[[ "$(tail -n +2 "${COMMAND_OS_UPDATES_DIR}/updates")" == 'linux 7.2.7.arch1-1 -> 7.2.8.arch1-2' ]] \
  && ok "guarda la lista tal cual" || mal "la lista guardada no coincide"
head -n 1 "${COMMAND_OS_UPDATES_DIR}/updates" | grep -qE '^[0-9]{10}$' && ok "primera línea: la hora" || mal "falta la hora"
[[ "$(stat -c %a "${COMMAND_OS_UPDATES_DIR}/updates")" == 644 ]] && ok "legible por todos (644)" || mal "permisos del resultado"

: > "${FALSO_SALIDA}"
PATH="${FALSO}:${PATH}" FALSO_CODIGO=2 "${CHECK}" manual && ok "sin novedades (código 2): termina bien" || mal "el código 2 no es un error"
[[ "$(wc -l < "${COMMAND_OS_UPDATES_DIR}/updates")" == 1 ]] && ok "queda solo la hora" || mal "sin novedades debe quedar solo la hora"

printf 'previo 1-1 -> 2-1\n' >> "${COMMAND_OS_UPDATES_DIR}/updates"
mkdir -p "${CHECKUPDATES_DB}"
PATH="${FALSO}:${PATH}" FALSO_CODIGO=1 "${CHECK}" manual 2>/dev/null && mal "un fallo debe salir distinto de 0" || ok "con un fallo, sale con error"
grep -q 'previo' "${COMMAND_OS_UPDATES_DIR}/updates" && ok "un fallo conserva el resultado anterior" || mal "un fallo no debe borrar el resultado"
[[ -e "${CHECKUPDATES_DB}" ]] && mal "tras un fallo se borra la copia de la base de datos para reintentar de cero" \
  || ok "tras un fallo, la copia de la base de datos se borra y se reintenta de cero"
[[ -z "$(find "${COMMAND_OS_UPDATES_DIR}" -name '.updates.*')" ]] && ok "sin archivos temporales sueltos" || mal "quedan temporales"

printf '#!/bin/sh\necho "u 3"\n' > "${FALSO}/busctl"
chmod +x "${FALSO}/busctl"
printf 'nuevo 1-1 -> 2-1\n' > "${FALSO_SALIDA}"
rm -f "${COMMAND_OS_UPDATES_DIR}/updates"
PATH="${FALSO}:${PATH}" FALSO_CODIGO=0 "${CHECK}" auto >/dev/null 2>&1
[[ ! -e "${COMMAND_OS_UPDATES_DIR}/updates" ]] && ok "datos medidos (auto): no comprueba" || mal "con datos medidos no debe comprobar en modo auto"
PATH="${FALSO}:${PATH}" FALSO_CODIGO=0 "${CHECK}" manual >/dev/null 2>&1
[[ -e "${COMMAND_OS_UPDATES_DIR}/updates" ]] && ok "datos medidos (manual): comprueba" || mal "a mano debe comprobar siempre"
"${CHECK}" raro >/dev/null 2>&1 && mal "acepta un modo desconocido" || ok "rechaza un modo desconocido"

echo "==> Unidades, gancho y permiso"
if command -v systemd-analyze >/dev/null; then
  if salida=$(systemd-analyze verify command-os-check-updates@auto.service command-os-check-updates.timer 2>&1); then
    ok "systemd-analyze verify: unidades válidas"
  else
    echo "${salida}"; mal "systemd-analyze verify"
  fi
fi
for f in /usr/share/libalpm/hooks/command-os-updates.hook /usr/share/polkit-1/rules.d/50-command-os-check-updates.rules; do
  [[ -f "${f}" ]] && ok "instalado: ${f}" || mal "falta ${f}"
done
/usr/lib/command-os/refresh-updates && ok "refresh-updates no falla fuera de systemd" || mal "refresh-updates no debe fallar nunca"

echo
if (( fallos )); then echo "==> ${fallos} fallo(s)"; exit 1; fi
echo "==> Todo correcto"
