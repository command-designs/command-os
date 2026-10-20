#!/usr/bin/env bash
# Command OS — prueba del aviso de actualizaciones sin red ni pantalla: lo que enseña la barra
# (command-os-updates status) según lo que dejó la comprobación, la propia comprobación
# (lib/check-updates, con un `checkupdates` y un `busctl` de mentira) y las unidades de systemd.
#
# Se ejecuta en un Arch con el paquete instalado (GitHub Actions, ver .github/workflows/escritorio.yml).
# No toca el sistema: todo va a una carpeta temporal. Sale con 1 si algo falla.
# Sin pipefail a propósito: con `orden | grep -q texto`, grep sale al encontrar el texto y la orden de
# la izquierda puede morir por SIGPIPE si aún escribe; con pipefail eso daba fallos intermitentes.
set -u

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

echo "==> Aplicaciones de la tienda (Flatpak) en la barra"
TAB=$(printf '\t')
export COMMAND_OS_FLATPAK_CHANGED="${T}/flatpak-changed"
touch -d '1 hour ago' "${COMMAND_OS_PACMAN_LOCAL}" "${COMMAND_OS_FLATPAK_CHANGED}"
printf '%s\napp\tDiscord\t0.0.110\t0.0.111\napp\tadw-gtk3-dark\t\t\n' "${ahora}" > "${COMMAND_OS_UPDATES_STATE}"
[[ "$(clase)" == paquetes ]] && ok "solo aplicaciones: se enseña (clase «paquetes»)" || mal "con aplicaciones debe enseñarse"
estado | grep -q 'upd</span> 2"' && ok "cuenta 2 aplicaciones" || mal "debe contar 2 aplicaciones"
estado | grep -q 'Discord 0.0.110 → 0.0.111' && ok "el tooltip lista las aplicaciones con versiones" || mal "tooltip sin las aplicaciones"
estado | grep -q 'adw-gtk3-dark\\n' && ok "una aplicación sin versión sale solo con el nombre" || mal "aplicación sin versión mal escrita"
printf '%s\nflatpak 1.16.1-1 -> 1.16.2-1\napp\tDiscord\t0.0.110\t0.0.111\n' "${ahora}" > "${COMMAND_OS_UPDATES_STATE}"
estado | grep -q 'upd</span> 2"' && ok "paquetes y aplicaciones se suman" || mal "debe sumar paquetes y aplicaciones"
estado | grep -q '1 paquete de Arch' && ok "el paquete de pacman «flatpak» cuenta como paquete" || mal "una línea de pacman no es una aplicación"
printf '%s\ncommand-os 2026.10.07.0803-1 -> 2026.10.08.1200-1\napp\tDiscord\t0.0.110\t0.0.111\n' "${ahora}" > "${COMMAND_OS_UPDATES_STATE}"
estado | grep -q 'y 1 aplicación de la tienda' && ok "con command-os nuevo, el tooltip cuenta las aplicaciones" || mal "falta la cuenta de aplicaciones con command-os nuevo"
printf '%s\nlinux 7.2.7.arch1-1 -> 7.2.8.arch1-2\napp\tDiscord\t0.0.110\t0.0.111\n' "$((ahora - 600))" > "${COMMAND_OS_UPDATES_STATE}"
touch -d '1 minute ago' "${COMMAND_OS_FLATPAK_CHANGED}"
estado | grep -q 'upd</span> 1"' && ok "Flatpak cambió después: cuenta solo lo de pacman" || mal "tras un cambio de Flatpak no deben contar las aplicaciones"
printf '%s\napp\tDiscord\t0.0.110\t0.0.111\n' "$((ahora - 600))" > "${COMMAND_OS_UPDATES_STATE}"
[[ "$(clase)" == ninguna ]] && ok "solo aplicaciones y Flatpak cambió después: oculto" || mal "una comprobación de aplicaciones vieja no debe enseñarse"
touch -d '1 hour ago' "${COMMAND_OS_FLATPAK_CHANGED}"

echo 'basura' > "${COMMAND_OS_UPDATES_STATE}"
[[ "$(clase)" == ninguna ]] && ok "archivo corrupto: oculto" || mal "un archivo corrupto no debe romper la barra"
command-os-updates nada >/dev/null 2>&1 && mal "acepta una orden desconocida" || ok "rechaza una orden desconocida"

echo "==> Lo que lee el panel (command-os-updates datos)"
datos() { command-os-updates datos; }
touch -d '1 hour ago' "${COMMAND_OS_PACMAN_LOCAL}"
rm -f "${COMMAND_OS_UPDATES_STATE}"
[[ "$(datos)" == nada ]] && ok "sin comprobación: «nada» y sin hora" || mal "sin comprobación debe salir solo «nada»"
echo "${ahora}" > "${COMMAND_OS_UPDATES_STATE}"
[[ "$(datos | tail -n 1)" == nada ]] && datos | grep -q "^hace$(printf '\t')" \
  && ok "al día: «nada» con la hora de la comprobación" || mal "al día debe dar la hora y «nada»"
printf '%s\ncommand-os 2026.10.07.0803-1 -> 2026.10.08.1200-1\nlinux 7.2.7.arch1-1 -> 7.2.8.arch1-2\nmesa 26.1.0-1 -> 26.1.1-1\n' "${ahora}" > "${COMMAND_OS_UPDATES_STATE}"
TAB=$(printf '\t')
datos | grep -qx "command-os${TAB}2026.10.07.0803${TAB}2026.10.08.1200" && ok "versiones de command-os (sin el -1)" || mal "faltan las versiones de command-os"
datos | grep -qx "paquete${TAB}linux${TAB}7.2.7.arch1-1${TAB}7.2.8.arch1-2" && ok "un paquete por línea, sin la flecha" || mal "línea de paquete mal formada"
[[ "$(datos | grep -c '^paquete')" == 2 ]] && ok "cuenta los paquetes de Arch (2)" || mal "debe haber 2 paquetes"
datos | grep -q "^arch${TAB}[01]$" && ok "dice si se aplica una fecha de Arch" || mal "falta la línea «arch»"
datos | grep -qx nada && mal "con novedades no debe salir «nada»" || ok "con novedades no sale «nada»"
printf '%s\nlinux 7.2.7.arch1-1 -> 7.2.8.arch1-2\n' "$((ahora - 3600))" > "${COMMAND_OS_UPDATES_STATE}"
touch -d '10 minutes ago' "${COMMAND_OS_PACMAN_LOCAL}"
[[ "$(datos)" == nada ]] && ok "comprobación anterior a un cambio de pacman: «nada»" || mal "una comprobación vieja no debe enseñarse en el panel"
touch -d '1 hour ago' "${COMMAND_OS_PACMAN_LOCAL}"
printf '%s\napp\tDiscord\t0.0.110\t0.0.111\napp\tadw-gtk3-dark\t\t\n' "${ahora}" > "${COMMAND_OS_UPDATES_STATE}"
datos | grep -qx "app${TAB}Discord${TAB}0.0.110${TAB}0.0.111" && ok "una aplicación por línea" || mal "línea de aplicación mal formada"
datos | grep -qx "app${TAB}adw-gtk3-dark${TAB}${TAB}" && ok "las versiones vacías se conservan" || mal "una aplicación sin versión pierde campos"
datos | grep -qx nada && mal "con solo aplicaciones no debe salir «nada»" || ok "con solo aplicaciones no sale «nada»"

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
# Flatpak de mentira: `list` da lo instalado y `remote-ls` lo que tiene versión nueva. Sin
# FALSO_FP_LISTA no hay nada instalado. Como root, check-updates lo lanza como nobody: la carpeta
# temporal tiene que dejarle entrar.
cat > "${FALSO}/flatpak" <<'FAKE'
#!/bin/sh
case "$1" in
  list) [ -n "${FALSO_FP_LISTA:-}" ] && cat "${FALSO_FP_LISTA}"; exit 0 ;;
  remote-ls) : > "${HOME}/remote-ls"
    [ -n "${FALSO_FP_NUEVAS:-}" ] && cat "${FALSO_FP_NUEVAS}"; exit "${FALSO_FP_CODIGO:-0}" ;;
esac
exit 1
FAKE
chmod +x "${FALSO}/flatpak"
chmod 755 "${T}"
export FALSO_SALIDA="${T}/salida" COMMAND_OS_FLATPAK_CACHE="${T}/fpcache"

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
rm -f "${FALSO}/busctl"

echo "==> Las aplicaciones de la tienda en la comprobación"
printf 'linux 7.2.7.arch1-1 -> 7.2.8.arch1-2\n' > "${FALSO_SALIDA}"
PATH="${FALSO}:${PATH}" FALSO_CODIGO=0 "${CHECK}" manual >/dev/null 2>&1
[[ ! -e "${COMMAND_OS_FLATPAK_CACHE}/remote-ls" ]] && ok "sin aplicaciones instaladas no se mira Flathub" || mal "sin aplicaciones no debe descargar el resumen de Flathub"
! grep -q "^app${TAB}" "${COMMAND_OS_UPDATES_DIR}/updates" && ok "sin aplicaciones, ninguna línea «app»" || mal "líneas «app» de más"

export FALSO_FP_LISTA="${T}/fp-lista" FALSO_FP_NUEVAS="${T}/fp-nuevas"
printf 'com.discordapp.Discord/x86_64/stable\t0.0.110\norg.gtk.Gtk3theme.adw-gtk3-dark/x86_64/3.22\t\nmuy.Quieta/x86_64/stable\t1.0\n' > "${FALSO_FP_LISTA}"
printf 'app/com.discordapp.Discord/x86_64/stable\tDiscord\t0.0.111\nruntime/org.gtk.Gtk3theme.adw-gtk3-dark/x86_64/3.22\t\t\n' > "${FALSO_FP_NUEVAS}"
PATH="${FALSO}:${PATH}" FALSO_CODIGO=0 "${CHECK}" manual >/dev/null 2>&1
r="${COMMAND_OS_UPDATES_DIR}/updates"
grep -qx 'linux 7.2.7.arch1-1 -> 7.2.8.arch1-2' "${r}" && ok "lo de pacman sigue en el resultado" || mal "falta lo de pacman"
grep -qx "app${TAB}Discord${TAB}0.0.110${TAB}0.0.111" "${r}" && ok "aplicación con nombre y las dos versiones" || mal "línea de Discord mal formada: $(grep '^app' "${r}")"
grep -qx "app${TAB}org.gtk.Gtk3theme.adw-gtk3-dark/x86_64/3.22${TAB}${TAB}" "${r}" && ok "sin nombre: el ref, sin «runtime/»" || mal "línea sin nombre mal formada"
[[ "$(grep -c "^app${TAB}" "${r}")" == 2 ]] && ok "solo las que tienen versión nueva (2)" || mal "debe haber 2 aplicaciones"
if (( EUID == 0 )); then
  [[ "$(stat -c %U "${COMMAND_OS_FLATPAK_CACHE}")" == nobody ]] && ok "la caché de Flatpak es de nobody" || mal "la caché de Flatpak debe ser de nobody"
fi

PATH="${FALSO}:${PATH}" FALSO_CODIGO=0 FALSO_FP_CODIGO=1 "${CHECK}" manual >/dev/null 2>&1 \
  && ok "si Flatpak falla, la comprobación termina bien" || mal "un fallo de Flatpak no debe tumbar lo de pacman"
grep -qx 'linux 7.2.7.arch1-1 -> 7.2.8.arch1-2' "${r}" && ! grep -q "^app${TAB}" "${r}" \
  && ok "si Flatpak falla, sale lo de pacman sin aplicaciones" || mal "con Flatpak fallando debe quedar solo lo de pacman"
unset FALSO_FP_LISTA FALSO_FP_NUEVAS

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
