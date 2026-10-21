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

echo "==> Gestionar cuentas (lib/gestionar-cuentas, lo que hace el panel de cuentas)"
GC=/usr/lib/command-os/gestionar-cuentas
uid_ana=$(id -u ana)
# gc QUIEN ENTRADA ARGS… — ejecuta el ayudante como lo lanzaría pkexec (PKEXEC_UID = quien lo pide), con la
# entrada por stdin; deja «ok» o el código de error en $R.
gc() {
  local quien=$1 entrada=$2 e rc
  shift 2
  e=$(printf '%s' "${entrada}" | PKEXEC_UID=${quien} "${GC}" "$@" 2>&1 >/dev/null)
  rc=$?
  if (( rc == 0 )); then R=ok; else R=$(sed -n 's/^error: //p' <<< "${e}"); fi
}
espero() { [[ "${R}" == "$1" ]] && ok "$2" || mal "$2 (salió «${R}», se esperaba «$1»)"; }
CLAVE2='otra-clave-9f3'
R=$(printf '' | env -u PKEXEC_UID "${GC}" zona UTC 2>&1 >/dev/null | sed -n 's/^error: //p')
espero sin_permiso "sin pkexec (PKEXEC_UID) no hace nada"
gc "${uid_ana}" "${CLAVE}"$'\n' anadir 'Luis Pérez';            espero usuario_invalido "usuario con espacios o tildes: rechazado"
gc "${uid_ana}" $'corta\n' anadir luis;                         espero clave_corta "contraseña corta: rechazada"
gc "${uid_ana}" $'ñañañañ\n' anadir luis;                       espero clave_corta "7 caracteres con ñ (10 bytes): rechazada"
( export LC_ALL=C; source /usr/lib/command-os/reglas.sh
  contrasena_corta 'ñañañañ' && ! contrasena_corta 'ñañañañá' ) \
  && ok "longitud en caracteres aun sin locale UTF-8 (7 cortos, 8 valen)" || mal "contrasena_corta cuenta bytes"
gc "${uid_ana}" "${CLAVE}"$'\n' anadir ana;                     espero usuario_existe "usuario que ya existe: rechazado"
gc "${uid_ana}" "${CLAVE}"$'\n' anadir video;                   espero nombre_reservado "nombre de grupo del sistema: rechazado"
gc "${uid_ana}" "${CLAVE}"$'\n' anadir luis --idioma fr_FR.UTF-8; espero idioma_no_disponible "idioma que no está en la lista: rechazado"
getent passwd luis >/dev/null && mal "quedó la cuenta luis tras un idioma inválido" || ok "no queda ninguna cuenta a medias"
gc "${uid_ana}" "${CLAVE}"$'\n' anadir luis --nombre 'Luis Pérez' --idioma es_ES.UTF-8; espero ok "crea una cuenta normal con idioma propio"
id -nG luis 2>/dev/null | grep -qw wheel && mal "la cuenta nueva es administradora sin pedirlo" || ok "la cuenta nueva no es administradora de serie"
[[ "$(getent passwd luis | cut -d: -f5)" == 'Luis Pérez' ]] && ok "guarda el nombre completo" || mal "nombre completo"
[[ "$(getent shadow luis | cut -d: -f2)" == \$y\$* ]] && ok "contraseña guardada como hash" || mal "hash de la contraseña de luis"
[[ "$(cat /home/luis/.config/locale.conf 2>/dev/null)" == 'LANG=es_ES.UTF-8' && "$(stat -c %U /home/luis/.config/locale.conf)" == luis ]] \
  && ok "idioma propio: ~/.config/locale.conf de la cuenta" || mal "no se escribió el idioma propio"
# La sesión de luis (lib/entorno-grafico) usa su idioma, no el del sistema (en_US en este equipo).
[[ "$(HOME=/home/luis bash -c '. /usr/lib/command-os/entorno-grafico; echo "${LANG}"')" == es_ES.UTF-8 ]] \
  && ok "la sesión usa el idioma propio de la cuenta" || mal "entorno-grafico no aplica el idioma de la cuenta"
[[ "$(HOME=/home/nadie bash -c '. /usr/lib/command-os/entorno-grafico; echo "${LANG}"')" == en_US.UTF-8 ]] \
  && ok "sin idioma propio, el del sistema" || mal "sin idioma propio no sale el del sistema"
gc "${uid_ana}" "" idioma luis sistema;                         espero ok "idioma «del sistema»"
[[ ! -e /home/luis/.config/locale.conf ]] && ok "quita el archivo del idioma propio" || mal "queda el idioma propio"
gc "${uid_ana}" "" idioma luis fr_FR.UTF-8;                     espero idioma_no_disponible "idioma propio inválido"
gc "${uid_ana}" "" idioma nadie es_ES.UTF-8;                    espero no_existe "idioma de una cuenta que no existe"
# Un enlace simbólico en la carpeta de la cuenta no puede llevar la escritura fuera de ella: el archivo
# se escribe como la propia cuenta, no como root.
rm -rf /home/luis/.config
ln -s /etc/command-os /home/luis/.config
gc "${uid_ana}" "" idioma luis es_ES.UTF-8;                     espero fallo "un enlace simbólico en su carpeta no desvía la escritura"
[[ ! -e /etc/command-os/locale.conf ]] && ok "no se escribió nada fuera de la carpeta de la cuenta" || mal "escribió a través del enlace"
rm -f /home/luis/.config
gc "${uid_ana}" "${CLAVE}"$'\n' anadir marta --admin;           espero ok "crea una cuenta administradora"
id -nG marta 2>/dev/null | grep -qw wheel && ok "marta está en wheel" || mal "marta no es administradora"
gc "${uid_ana}" "" admin luis si;                               espero ok "dar permiso de administrar"
id -nG luis | grep -qw wheel && ok "luis ahora es administrador" || mal "luis no entró en wheel"
gc "${uid_ana}" "" admin luis no;                               espero ok "quitar el permiso"
id -nG luis | grep -qw wheel && mal "luis sigue en wheel" || ok "luis ya no es administrador"
gc "${uid_ana}" "" admin ana no;                                espero es_la_propia "no se quita el permiso a uno mismo"
gc "${uid_ana}" "${CLAVE2}"$'\n' clave luis;                    espero ok "poner otra contraseña a una cuenta"
gc "${uid_ana}" $'corta\n' clave luis;                          espero clave_corta "contraseña corta en el cambio"
gc "${uid_ana}" "${CLAVE2}"$'\n' clave root;                    espero no_existe "root no es una cuenta de personas"
gc "${uid_ana}" "" borrar ana;                                  espero es_la_propia "no se borra la cuenta de quien lo pide"
gc "${uid_ana}" "" borrar nobody;                               espero no_existe "no se borran cuentas del sistema"
# Sin más administradores que ana, ni se le quita el permiso ni se borra (lo pide otra cuenta).
gc "${uid_ana}" "" admin marta no;                              espero ok "quita a marta (queda ana)"
gc "${uid_ana}" "" admin viejo no;                              espero ok "quita a viejo (queda ana)"
uid_luis=$(id -u luis)
gc "${uid_luis}" "" admin ana no;                               espero ultimo_admin "no se quita al último administrador"
gc "${uid_luis}" "" borrar ana;                                 espero ultimo_admin "no se borra al último administrador"
gc "${uid_ana}" "" borrar luis --conservar-home;                espero ok "borrar conservando la carpeta personal"
getent passwd luis >/dev/null && mal "luis sigue existiendo" || ok "la cuenta ya no existe"
[[ -d /home/luis ]] && ok "su carpeta personal se conserva" || mal "se borró la carpeta aunque se pidió conservarla"
# Su UID queda libre y una cuenta nueva puede recibirlo: la carpeta conservada no puede seguir con él.
[[ "$(stat -c '%U %a' /home/luis)" == 'root 700' ]] && ok "la carpeta conservada pasa a root (700): una cuenta nueva con el mismo UID no la hereda" \
  || mal "la carpeta conservada sigue accesible ($(stat -c '%U %a' /home/luis))"
[[ -z "$(find /home/luis -not -user root 2>/dev/null | head -n 1)" ]] && ok "y nada dentro sigue con el UID de la cuenta borrada" || mal "quedan archivos con el UID viejo"
gc "${uid_ana}" "" borrar marta;                                espero ok "borrar con la carpeta"
[[ ! -d /home/marta ]] && ok "se borra su carpeta personal" || mal "queda la carpeta de marta"
gc "${uid_ana}" "" borrar marta;                                espero no_existe "borrar una cuenta que ya no está"
# Una carpeta conservada fuera de /home también se cede a root (el UID puede reutilizarse igual).
mkdir -p /srv/h7
gc "${uid_ana}" "${CLAVE}"$'\n' anadir prueba7;                 espero ok "cuenta con la carpeta en otra ruta"
usermod -d /srv/h7 prueba7 && echo dato > /srv/h7/x && chown -R prueba7: /srv/h7
gc "${uid_ana}" "" borrar prueba7 --conservar-home;             espero ok "borrar conservando una carpeta fuera de /home"
[[ "$(stat -c '%U %a' /srv/h7)" == 'root 700' && "$(stat -c %U /srv/h7/x)" == root ]] \
  && ok "también pasa a root (700)" || mal "la carpeta de fuera de /home sigue accesible"
rm -rf /srv/h7
# Si el idioma falla después de crear la cuenta, no queda a medias (aquí /home no deja entrar a la cuenta).
chmod 000 /home
gc "${uid_ana}" "${CLAVE}"$'\n' anadir prueba8 --idioma es_ES.UTF-8; espero idioma_no_disponible "idioma que falla al escribirse: error"
chmod 755 /home
getent passwd prueba8 >/dev/null && mal "quedó la cuenta prueba8 a medias" || ok "y no queda la cuenta creada"
# Si se borra la cuenta principal, el equipo pasa a la primera administradora y greetd lo sigue.
gc "${uid_ana}" "" admin viejo si;                              espero ok "viejo vuelve a ser administrador"
command-os-login auto ana >/dev/null
gc "$(id -u viejo)" "" borrar ana;                              espero ok "viejo borra la cuenta principal"
[[ "$(cat /etc/command-os/cuenta-principal)" == viejo ]] && ok "la cuenta principal pasa a viejo" || mal "cuenta-principal no se actualizó"
[[ ! -s /etc/command-os/inicio-automatico ]] && ok "se quita el inicio automático de la cuenta borrada" || mal "queda el inicio automático de ana"
grep -q 'user = "ana"' "${TOML}" && mal "greetd sigue usando a ana" || ok "greetd ya no usa la cuenta borrada"
gc "$(id -u viejo)" "" zona Europe/Madrid;                      espero ok "cambiar la zona horaria"
[[ "$(command-os-zona-horaria actual)" == Europe/Madrid ]] && ok "la zona queda aplicada" || mal "no se aplicó la zona"
gc "$(id -u viejo)" "" zona Mars/Olympus;                       espero zona_no_disponible "zona que no existe"
# El idioma de todo el equipo (Ajustes → idioma y hora): solo los de command-os-idioma lista.
idioma_antes=$(sed -n 's/^LANG=//p' /etc/locale.conf 2>/dev/null)
gc "$(id -u viejo)" "" idioma-equipo en_US.UTF-8;               espero ok "cambiar el idioma del equipo"
grep -qx 'LANG=en_US.UTF-8' /etc/locale.conf && ok "el idioma del equipo queda en locale.conf" || mal "locale.conf: $(cat /etc/locale.conf)"
gc "$(id -u viejo)" "" idioma-equipo '../../etc/passwd';        espero idioma_no_disponible "idioma que no es de la lista"
gc "$(id -u viejo)" "" idioma-equipo "${idioma_antes:-es_ES.UTF-8}"; espero ok "y vuelve al de antes"
gc "$(id -u viejo)" "" nada;                                    espero fallo "orden desconocida"

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

echo "==> Reglas de las cuentas: la copia en shell (lib/reglas.sh) y la de Python (lib/comun.py) coinciden"
py=$(PYTHONPATH=/usr/lib/command-os python3 -W ignore -c 'import comun; print(comun.MIN_CONTRASENA, comun.USUARIO_ER)' 2>/dev/null)
# shellcheck source=../os/lib/reglas.sh
sh=$(source /usr/lib/command-os/reglas.sh; patron=$(grep -oE '\^\[a-z\][^$]*' /usr/lib/command-os/reglas.sh | head -n1); echo "${MIN_CONTRASENA} ${patron#^}")
[[ -n "${py}" && "${py}" == "${sh}" ]] && ok "longitud mínima y patrón de usuario iguales en shell y Python" \
  || mal "lib/reglas.sh (${sh}) y lib/comun.py (${py}) tienen reglas distintas"

echo
if (( fallos )); then echo "==> ${fallos} fallo(s)"; exit 1; fi
echo "==> Todo bien"
