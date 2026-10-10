#!/usr/bin/env bash
# Command OS — prueba de la entrada al equipo sin pantalla: crear la cuenta principal
# (lib/crear-cuenta), los modos de command-os-login, la configuración de greetd (lib/apply-login) y
# la migración de los equipos que entraban con agetty --autologin.
#
# Se ejecuta como root en un Arch con el paquete instalado y sin cuenta principal (GitHub Actions,
# ver .github/workflows/escritorio.yml). Modifica cuentas del sistema: solo en un contenedor
# desechable. Sale con 1 si algo falla.
# Sin pipefail a propósito: con `orden | grep -q texto`, grep sale al encontrar el texto y la orden de
# la izquierda puede morir por SIGPIPE si aún escribe; con pipefail eso daba fallos intermitentes.
set -u

fallos=0
ok() { echo "  ok   $*"; }
mal() { echo "  MAL  $*"; fallos=$((fallos + 1)); }
TOML=/etc/command-os/greetd.toml
CREAR=/usr/lib/command-os/crear-cuenta
CLAVE='clave-de-prueba-9f3'

echo "==> Equipo recién instalado"
rm -f /var/lib/command-os/configurado /etc/command-os/{cuenta-principal,inicio-automatico}
/usr/lib/command-os/apply-login
grep -q 'command = "command-os-primer-arranque"' "${TOML}" && ok "sin cuenta: asistente de primer arranque" \
  || mal "sin cuenta, greetd no abre el asistente"
grep -q initial_session "${TOML}" && mal "sin cuenta no debe haber inicio automático" || ok "sin inicio automático"
visudo -c -f /etc/sudoers.d/10-command-os-wheel >/dev/null && ok "sudoers de wheel válido" || mal "sudoers de wheel"

echo "==> Datos no válidos (no deben crear nada)"
echo "${CLAVE}" | "${CREAR}" --usuario 'Ana López' >/dev/null 2>&1 && mal "acepta un usuario con espacios" || ok "rechaza usuario con espacios"
echo "${CLAVE}" | "${CREAR}" --usuario root >/dev/null 2>&1 && mal "acepta root" || ok "rechaza un usuario que ya existe"
echo "corta" | "${CREAR}" --usuario ana >/dev/null 2>&1 && mal "acepta una contraseña corta" || ok "rechaza contraseña corta"
echo "${CLAVE}" | "${CREAR}" --usuario ana --teclado 'es;rm' >/dev/null 2>&1 && mal "acepta un teclado raro" || ok "rechaza teclado no válido"
echo "${CLAVE}" | "${CREAR}" --usuario ana --idioma fr_FR.UTF-8 >/dev/null 2>&1 && mal "acepta un idioma que no está en la lista" || ok "rechaza idiomas que no están en la lista"
echo "${CLAVE}" | "${CREAR}" --usuario ana --zona ../../etc/passwd >/dev/null 2>&1 && mal "acepta una zona que no es de la lista" || ok "rechaza zonas que no están en la lista"
# Si falla un paso después de la zona (aquí, el idioma), la zona vuelve a la de antes.
command-os-zona-horaria Europe/Madrid >/dev/null
falso=$(mktemp -d)
printf '#!/bin/sh\n[ "$1" = lista ] && exec /usr/bin/command-os-idioma lista\nexit 1\n' > "${falso}/command-os-idioma"
chmod +x "${falso}/command-os-idioma"
echo "${CLAVE}" | PATH="${falso}:${PATH}" "${CREAR}" --usuario ana --zona America/New_York --idioma en_US.UTF-8 >/dev/null 2>&1 \
  && mal "crea la cuenta aunque falle el idioma" || ok "si falla el idioma, no crea la cuenta"
[[ "$(command-os-zona-horaria actual)" == Europe/Madrid ]] && ok "y la zona vuelve a la de antes" \
  || mal "la zona quedó en $(command-os-zona-horaria actual) tras el fallo"
rm -rf "${falso}"
echo "${CLAVE}" | "${CREAR}" --usuario video >/dev/null 2>&1 && mal "acepta un nombre de grupo del sistema"   || ok "rechaza nombres de grupos del sistema"
getent passwd video >/dev/null && mal "quedó la cuenta video"
getent passwd ana >/dev/null && mal "quedó una cuenta a medias" || ok "no quedan cuentas a medias"
[[ -e /var/lib/command-os/configurado ]] && mal "se marcó como configurado tras un error" || ok "sigue sin configurar"

echo "==> Cuenta principal"
if echo "${CLAVE}" | "${CREAR}" --usuario ana --nombre 'Ana López' --teclado 'de(nodeadkeys)' --idioma en_US.UTF-8 \
    --zona America/New_York >/dev/null; then
  ok "crear-cuenta ana"
else
  mal "crear-cuenta ana"
fi
id -nG ana 2>/dev/null | grep -qw wheel && ok "ana es administradora (wheel)" || mal "ana no está en wheel"
[[ "$(getent shadow ana | cut -d: -f2)" == \$y\$* ]] && ok "contraseña guardada como hash yescrypt" || mal "hash de la contraseña"
[[ "$(passwd -S root | awk '{print $2}')" == L ]] && ok "root bloqueado" || mal "root no está bloqueado"
if grep -rqsF "${CLAVE}" /etc /var/lib/command-os /var/log /home /root /tmp 2>/dev/null; then
  mal "la contraseña aparece en claro en algún archivo"
else
  ok "la contraseña no aparece en claro en ningún archivo"
fi
[[ "$(cat /etc/command-os/kb_layout)" == 'de(nodeadkeys)' ]] && ok "teclado con variante guardado" || mal "teclado"
grep -qx 'LANG=en_US.UTF-8' /etc/locale.conf && ok "idioma elegido en locale.conf" || mal "no se aplicó el idioma"
[[ "$(readlink /etc/localtime)" == */zoneinfo/America/New_York ]] && ok "zona horaria elegida" || mal "no se aplicó la zona horaria"
grep -q 'command = "command-os-greeter"' "${TOML}" && ok "greetd: pantalla de inicio de sesión" || mal "greetd sin pantalla de inicio de sesión"
grep -q initial_session "${TOML}" && mal "inicio automático sin pedirlo" || ok "pide contraseña (por defecto)"
echo "${CLAVE}" | "${CREAR}" --usuario luis >/dev/null 2>&1 && mal "se puede repetir el primer arranque" || ok "no se repite"

echo "==> command-os-login"
command-os-login auto >/dev/null && grep -q 'user = "ana"' "${TOML}" && grep -q initial_session "${TOML}" \
  && ok "auto: entra sola como ana" || mal "command-os-login auto"
command-os-login auto nadie >/dev/null 2>&1 && mal "auto con un usuario que no existe" || ok "auto rechaza usuarios inexistentes"
command-os-login auto nobody >/dev/null 2>&1 && mal "auto acepta nobody" || ok "auto rechaza cuentas que no son de personas"
command-os-login pedir >/dev/null && ! grep -q initial_session "${TOML}" && ok "pedir: sin inicio automático" \
  || mal "command-os-login pedir"

echo "==> Migración desde agetty --autologin"
useradd -m -G wheel -s /bin/bash viejo
rm -f /var/lib/command-os/configurado /etc/command-os/{cuenta-principal,inicio-automatico}
install -d /etc/systemd/system/getty@tty1.service.d
printf '[Service]\nExecStart=\nExecStart=-/usr/bin/agetty --autologin viejo --noclear %%I $TERM\n' \
  > /etc/systemd/system/getty@tty1.service.d/override.conf
printf 'antes\n# --- Command OS: autostart labwc on tty1 ---\nif true; then\n  exec labwc\nfi\ndespues\n' \
  > /home/viejo/.bash_profile
/usr/lib/command-os/apply-login
[[ -e /var/lib/command-os/configurado ]] && ok "queda configurado sin asistente" || mal "no se migró"
grep -q 'user = "viejo"' "${TOML}" && grep -q initial_session "${TOML}" && ok "sigue entrando solo con su cuenta" \
  || mal "la migración perdió el inicio automático"
[[ ! -e /etc/systemd/system/getty@tty1.service.d/override.conf ]] && ok "agetty --autologin retirado" || mal "queda el agetty"
if grep -q labwc /home/viejo/.bash_profile || ! grep -q despues /home/viejo/.bash_profile; then
  mal ".bash_profile mal limpiado"
else
  ok ".bash_profile: fuera solo el bloque de labwc"
fi

echo "==> Disco cifrado: el asistente propone entrar sin contraseña (lib/comun.py disco_cifrado)"
cifrado() { PYTHONPATH=/usr/lib/command-os python3 -W ignore -c 'import sys; from comun import disco_cifrado; print(disco_cifrado(sys.argv[1]))' "$1" 2>/dev/null; }
CMD=$(mktemp)
echo 'BOOT_IMAGE=/vmlinuz-linux root=UUID=x rw cryptdevice=UUID=abc:command-os root=/dev/mapper/command-os quiet' > "${CMD}"
[[ "$(cifrado "${CMD}")" == True ]] && ok "con cryptdevice= en la línea del kernel: cifrado" || mal "no detecta el disco cifrado"
echo 'BOOT_IMAGE=/vmlinuz-linux root=UUID=x rw quiet command-os.idioma=es' > "${CMD}"
[[ "$(cifrado "${CMD}")" == False ]] && ok "sin cryptdevice=: no cifrado" || mal "da por cifrado un disco que no lo está"
echo 'root=UUID=x notcryptdevice=1' > "${CMD}"
[[ "$(cifrado "${CMD}")" == False ]] && ok "una palabra que solo lo contiene no cuenta" || mal "detecta cryptdevice= dentro de otra palabra"
[[ "$(cifrado /no/existe)" == False ]] && ok "sin línea del kernel legible: no cifrado" || mal "falla sin /proc/cmdline"
rm -f "${CMD}"

echo
if (( fallos )); then echo "==> ${fallos} fallo(s)"; exit 1; fi
echo "==> Todo bien"
