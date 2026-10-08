#!/usr/bin/env bash
# Command OS — prueba de la seguridad del instalador en disco entero (build/x86/lib.sh e
# install-disco.sh): qué discos rechaza, la confirmación, el particionado y que nunca toca otro
# disco. Solo con discos loop sobre archivos temporales: no mira ni toca ningún disco real.
#
# También el cifrado: las preguntas (contraseña, clave de recuperación), el particionado con /boot,
# LUKS y el gancho del initramfs que abre el disco (con bash y, si está, con el ash de busybox).
#
# Necesita root, losetup, sgdisk (gdisk), mkfs.fat (dosfstools), mkntfs (ntfs-3g), cryptsetup y
# mkfs.ext4; busybox es opcional. Lo ejecuta GitHub Actions en ubuntu-latest
# (.github/workflows/pruebas.yml). Sale con 1 si algo falla.
set -uo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
# shellcheck source=../build/x86/lib.sh
source "${REPO}/build/x86/lib.sh"
fallos=0
ok() { echo "  ok   $*"; }
mal() { echo "  MAL  $*"; fallos=$((fallos + 1)); }
[[ $(id -u) -eq 0 ]] || { echo "ejecutar como root" >&2; exit 1; }

T=$(mktemp -d)
LOOPS=()
cleanup() {
  local l
  umount -q "${T}/montado" "${T}/raiz" 2>/dev/null
  for l in "${LUKS_NAME}" prueba-cifrado; do [[ -b "/dev/mapper/${l}" ]] && cryptsetup close "${l}"; done
  for l in "${LOOPS[@]}"; do losetup -d "${l}" 2>/dev/null; done
  rm -rf "${T}"
}
trap cleanup EXIT

# nuevo_loop NOMBRE TAMAÑO — disco loop sobre un archivo disperso; imprime /dev/loopN.
nuevo_loop() {
  truncate -s "$2" "${T}/$1.img"
  losetup --find --show --partscan "${T}/$1.img"
}
asentar() { partprobe "$1" 2>/dev/null; udevadm settle 2>/dev/null || sleep 2; }
problemas() { disk_problems "$1"; }
tiene() { grep -q -- "$2" <<< "$1"; }

export COMMAND_OS_DISCOS_LOOP=1

echo "==> Discos de prueba (loop)"
LIMPIO=$(nuevo_loop limpio 40G); LOOPS+=("${LIMPIO}")
PEQUENO=$(nuevo_loop pequeno 10G); LOOPS+=("${PEQUENO}")
WINDOWS=$(nuevo_loop windows 40G); LOOPS+=("${WINDOWS}")
MONTADO=$(nuevo_loop montado 40G); LOOPS+=("${MONTADO}")
USB=$(nuevo_loop usb 40G); LOOPS+=("${USB}")
SENUELO=$(nuevo_loop senuelo 2G); LOOPS+=("${SENUELO}")
VENTOY=$(nuevo_loop ventoy 40G); LOOPS+=("${VENTOY}")
sgdisk -n 1:0:0 -t 1:0700 "${VENTOY}" >/dev/null && asentar "${VENTOY}"
mkfs.fat -F32 -n Ventoy "$(part_path "${VENTOY}" 1)" >/dev/null

sgdisk -n 1:0:+2G -t 1:0c01 -n 2:0:0 -t 2:0700 "${WINDOWS}" >/dev/null && asentar "${WINDOWS}"
mkntfs -Q -F "$(part_path "${WINDOWS}" 2)" >/dev/null 2>&1
sgdisk -n 1:0:0 -t 1:8300 "${MONTADO}" >/dev/null && asentar "${MONTADO}"
mkfs.fat -F32 "$(part_path "${MONTADO}" 1)" >/dev/null
mkdir -p "${T}/montado" && mount "$(part_path "${MONTADO}" 1)" "${T}/montado"
sgdisk -n 1:0:0 -t 1:0700 "${USB}" >/dev/null && asentar "${USB}"
mkfs.fat -F32 -n ARCH_202609 "$(part_path "${USB}" 1)" >/dev/null
# Señuelo: un disco con datos que nada debe tocar en toda la prueba.
dd if=/dev/urandom of="${SENUELO}" bs=1M count=64 status=none
huella_senuelo=$(sha256sum < "${SENUELO}")
udevadm settle 2>/dev/null || sleep 2
ok "preparados"

echo "==> Qué discos se rechazan"
[[ -z "$(problemas "${LIMPIO}")" ]] && ok "disco limpio de 40 GB: se puede" || mal "rechaza un disco limpio: $(problemas "${LIMPIO}")"
tiene "$(problemas "${PEQUENO}")" "pequeño" && ok "rechaza un disco de 10 GB" || mal "acepta un disco pequeño"
tiene "$(problemas "${MONTADO}")" "montadas" && ok "rechaza un disco con particiones montadas" || mal "acepta un disco montado"
tiene "$(problemas "${USB}")" "USB de instalación" && ok "rechaza el USB en vivo (etiqueta ARCH_)" || mal "acepta el USB en vivo"
tiene "$(problemas "${VENTOY}")" "USB de instalación" && ok "rechaza un USB de Ventoy" || mal "acepta un USB de Ventoy"
tiene "$(problemas "$(part_path "${WINDOWS}" 2)")" "no un disco entero" && ok "rechaza una partición" || mal "acepta una partición"
tiene "$(problemas /dev/no-existe)" "no existe" && ok "rechaza un disco que no existe" || mal "acepta un disco que no existe"
tiene "$(COMMAND_OS_DISCOS_LOOP='' problemas "${LIMPIO}")" "no un disco entero" \
  && ok "sin modo de prueba, rechaza los discos loop" || mal "acepta discos loop fuera de las pruebas"
raiz=$(findmnt -nro SOURCE / 2>/dev/null)
disco_raiz=$(disk_of "${raiz}" 2>/dev/null | head -1)
if [[ -n "${disco_raiz}" ]]; then
  tiene "$(problemas "${disco_raiz}")" "sistema que está en marcha" \
    && ok "rechaza el disco del sistema en marcha (${disco_raiz})" || mal "acepta el disco del sistema en marcha"
else
  echo "  --   sin disco de bloque bajo / (${raiz:-?}): no se prueba el disco del sistema"
fi

echo "==> Windows y confirmación"
disk_has_windows "${WINDOWS}" && ok "detecta Windows (NTFS)" || mal "no detecta Windows"
disk_has_windows "${LIMPIO}" && mal "ve Windows en un disco limpio" || ok "disco limpio: sin Windows"
confirm_erase "${LIMPIO}" <<< "" >/dev/null 2>&1 && mal "Intro confirma el borrado" || ok "Intro no confirma"
confirm_erase "${LIMPIO}" <<< "SI" >/dev/null 2>&1 && mal "«SI» confirma el borrado" || ok "«SI» no confirma"
confirm_erase "${LIMPIO}" <<< "${SENUELO}" >/dev/null 2>&1 && mal "el nombre de otro disco confirma" || ok "el nombre de otro disco no confirma"
confirm_erase "${LIMPIO}" <<< "${LIMPIO}" >/dev/null 2>&1 && ok "el nombre exacto confirma" || mal "el nombre exacto no confirma"
confirm_erase "${WINDOWS}" <<< "${WINDOWS}" >/dev/null 2>&1 && mal "con Windows basta el nombre" || ok "con Windows no basta el nombre"
printf '%s\nBORRAR WINDOWS\n' "${WINDOWS}" | confirm_erase "${WINDOWS}" >/dev/null 2>&1 \
  && ok "con Windows: nombre y BORRAR WINDOWS" || mal "con Windows no acepta la frase"
printf '%s\nERASE WINDOWS\n' "${WINDOWS}" | confirm_erase "${WINDOWS}" >/dev/null 2>&1 \
  && mal "en castellano acepta ERASE WINDOWS" || ok "en castellano, ERASE WINDOWS no confirma"
confirmar_si <<< "SI" >/dev/null 2>&1 && ok "dual boot: SI confirma" || mal "dual boot: SI no confirma"
for r in "" si YES sí Si; do
  confirmar_si <<< "${r}" >/dev/null 2>&1 && mal "dual boot: «${r}» confirma" || ok "dual boot: «${r}» no confirma"
done
# En inglés (cargar_idioma), la frase y la palabra son las traducidas, y solo esas: las del otro
# idioma no borran. En un subproceso: el resto de pruebas sigue en castellano.
(
  fallos=0   # los de dentro: se suman fuera
  COMMAND_OS_IDIOMA=en cargar_idioma
  printf '%s\nERASE WINDOWS\n' "${WINDOWS}" | confirm_erase "${WINDOWS}" >/dev/null 2>&1 \
    && ok "en inglés: nombre y ERASE WINDOWS" || mal "en inglés no acepta ERASE WINDOWS"
  printf '%s\nBORRAR WINDOWS\n' "${WINDOWS}" | confirm_erase "${WINDOWS}" >/dev/null 2>&1 \
    && mal "en inglés acepta BORRAR WINDOWS" || ok "en inglés, BORRAR WINDOWS no confirma"
  confirm_erase "${WINDOWS}" <<< "${WINDOWS}" >/dev/null 2>&1 && mal "en inglés, con Windows basta el nombre" \
    || ok "en inglés, con Windows no basta el nombre"
  confirmar_si <<< "YES" >/dev/null 2>&1 && ok "en inglés, YES confirma el dual boot" || mal "en inglés, YES no confirma"
  confirmar_si <<< "SI" >/dev/null 2>&1 && mal "en inglés, SI confirma el dual boot" || ok "en inglés, SI no confirma"
  exit "${fallos}"
) || fallos=$((fallos + $?))

echo "==> Zona horaria de serie según el idioma"
# cargar_idioma en un subproceso (en inglés compila el catálogo y define gettext): el resto sigue en castellano.
zona_de() { ( unset TIMEZONE; [[ -n "${2:-}" ]] && export TIMEZONE=$2; COMMAND_OS_IDIOMA=$1 cargar_idioma 2>/dev/null; echo "${TIMEZONE}" ); }
[[ "$(zona_de es)" == Europe/Madrid ]] && ok "en castellano: Europe/Madrid" || mal "en castellano: $(zona_de es)"
[[ "$(zona_de en)" == UTC ]] && ok "en inglés: UTC" || mal "en inglés: $(zona_de en)"
[[ "$(zona_de es America/Bogota)" == America/Bogota ]] && ok "TIMEZONE manda en castellano" || mal "TIMEZONE no manda en castellano"
[[ "$(zona_de en Asia/Tokyo)" == Asia/Tokyo ]] && ok "TIMEZONE manda en inglés" || mal "TIMEZONE no manda en inglés"
grep -q 'Europe/Madrid}' "${REPO}"/build/x86/install-{disco,dualboot}.sh   && mal "un instalador vuelve a fijar la zona" || ok "los instaladores no fijan la zona por su cuenta"

echo "==> Rutas de las particiones"
for par in /dev/sda:/dev/sda1 /dev/nvme0n1:/dev/nvme0n1p1 /dev/mmcblk0:/dev/mmcblk0p1 /dev/loop7:/dev/loop7p1; do
  [[ "$(part_path "${par%%:*}" 1)" == "${par#*:}" ]] && ok "part_path ${par%%:*} → ${par#*:}" || mal "part_path ${par%%:*}"
done

echo "==> Particionado (disco limpio)"
( partition_whole_disk "${LIMPIO}" ) && ok "partition_whole_disk" || mal "partition_whole_disk falló"
tabla=$(sgdisk -p "${LIMPIO}" 2>/dev/null)
[[ "$(grep -cE '^ +[0-9]+ ' <<< "${tabla}")" == 2 ]] && ok "dos particiones" || mal "no hay dos particiones"
grep -qE '^ +1 .*1024\.0 MiB +EF00' <<< "${tabla}" && ok "1: EFI de 1 GiB (EF00)" || mal "la 1 no es la EFI de 1 GiB"
grep -qE '^ +2 .*8304 +command-os' <<< "${tabla}" && ok "2: raíz Linux x86-64 (8304) para el resto" || mal "la 2 no es la raíz"

echo "==> Cifrado: preguntas (lo que se pide antes de borrar)"
for par in "corta:al menos 8" "ñandú-1234:sin ñ" "contraseña:sin ñ" "café con leche:sin ñ"; do
  tiene "$(password_problem "${par%%:*}")" "${par#*:}" && ok "rechaza «${par%%:*}»" || mal "acepta «${par%%:*}»"
done
for buena in "buenaclave" "Con espacios y #simbolos!" '12345678'; do
  [[ -z "$(password_problem "${buena}")" ]] && ok "acepta «${buena}»" || mal "rechaza «${buena}»"
done
( printf 'corta\nñandú12345\nñandú12345\nbuenaclave\notraclave\nbuenaclave1\nbuenaclave1\n' \
  | { ask_disk_password >/dev/null 2>&1; [[ "${CLAVE_DISCO}" == buenaclave1 ]]; } ) \
  && ok "la contraseña se repite hasta que vale y coincide" || mal "ask_disk_password no se queda con la buena"
( ask_disk_password <<< "" >/dev/null 2>&1 ) && mal "sin respuesta sigue adelante" || ok "sin respuesta, cancela"
for par in ":si" "s:si" "Sí:si" "n:no" "NO:no" "quizá
n:no"; do
  r=${par%%:*}
  ( unset CIFRADO; ask_encryption <<< "${r}" >/dev/null 2>&1; [[ "${CIFRADO}" == "${par#*:}" ]] ) \
    && ok "«${r//$'\n'/ y luego }» → cifrar: ${par#*:}" || mal "«${r//$'\n'/ y luego }» no da ${par#*:}"
done
( CIFRADO=no; ask_encryption </dev/null >/dev/null 2>&1; [[ "${CIFRADO}" == no ]] ) \
  && ok "CIFRADO=no no pregunta" || mal "CIFRADO=no pregunta"
k1=$(new_recovery_key) k2=$(new_recovery_key)
[[ "${k1}" =~ ^[0-9]{48}$ && "${k1}" != "${k2}" ]] && ok "clave de recuperación: 48 cifras al azar" \
  || mal "clave de recuperación mal generada: ${k1}"
# Con set -e y pipefail, como en los instaladores (tr | head acabaría con SIGPIPE).
( set -e; k=$(new_recovery_key); [[ ${#k} == 48 ]] ) && ok "new_recovery_key funciona con set -e y pipefail" \
  || mal "new_recovery_key falla con set -e y pipefail"
# Clave fija (el grupo N son seis N) y RANDOM con semilla: se sabe qué dos grupos va a pedir (bash
# vuelve a sembrar RANDOM en cada subshell: la semilla va dentro, justo antes).
CLAVE_FIJA=111111222222333333444444555555666666777777888888
RANDOM=7; g1=$(( RANDOM % 4 + 1 )) g2=$(( RANDOM % 4 + 5 ))
( new_recovery_key() { echo "${CLAVE_FIJA}"; }
  printf '%s\n%s\n' "${g1}${g1}${g1}${g1}${g1}${g1}" "${g2}${g2}${g2}${g2}${g2}${g2}" \
    | { RANDOM=7; show_recovery_key >/dev/null 2>&1; [[ "${CLAVE_RECUPERACION:-}" == "${CLAVE_FIJA}" ]]; } ) \
  && ok "la clave de recuperación se comprueba con dos de sus grupos" || mal "no acepta los grupos buenos"
( new_recovery_key() { echo "${CLAVE_FIJA}"; }; show_recovery_key <<< $'000000\n000000' >/dev/null 2>&1 ) \
  && mal "sigue con grupos que no son" || ok "con grupos que no son, no sigue"

echo "==> Cifrado: particiones y LUKS (disco limpio)"
( partition_whole_disk "${LIMPIO}" cifrado ) && ok "partition_whole_disk cifrado" || mal "partition_whole_disk cifrado falló"
tabla=$(sgdisk -p "${LIMPIO}" 2>/dev/null)
[[ "$(grep -cE '^ +[0-9]+ ' <<< "${tabla}")" == 3 ]] && ok "tres particiones" || mal "no hay tres particiones"
grep -qE '^ +1 .*1024\.0 MiB +EF00' <<< "${tabla}" && ok "1: EFI de 1 GiB" || mal "la 1 no es la EFI de 1 GiB"
grep -qE '^ +2 .*1024\.0 MiB +8300 +command-os-boot' <<< "${tabla}" && ok "2: /boot de 1 GiB sin cifrar (8300)" || mal "la 2 no es /boot"
grep -qE '^ +3 .*8309 +command-os' <<< "${tabla}" && ok "3: LUKS (8309) para el resto" || mal "la 3 no es LUKS"
CIFRADA=$(part_path "${LIMPIO}" 3)
CLAVE_RECUPERACION=$(new_recovery_key)
recuperacion=${CLAVE_RECUPERACION}
CLAVE_DISCO="clave de prueba"
# Sin subshell: luks_root deja la marca para que close_luks sepa que el volumen es suyo (si falla,
# die cierra la prueba entera).
luks_root "${CIFRADA}" >/dev/null 2>&1
[[ -b "/dev/mapper/${LUKS_NAME}" && -z "${CLAVE_DISCO:-}${CLAVE_RECUPERACION:-}" ]] \
  && ok "luks_root cifra, abre /dev/mapper/${LUKS_NAME} y olvida las claves" || mal "luks_root falló"
CLAVE_DISCO=x CLAVE_RECUPERACION=y
( luks_root "${CIFRADA}" ) >/dev/null 2>&1 && mal "luks_root pisa un ${LUKS_NAME} ya abierto" \
  || ok "luks_root no sigue si ${LUKS_NAME} ya está abierto"
unset CLAVE_DISCO CLAVE_RECUPERACION
volcado=$(cryptsetup luksDump "${CIFRADA}" 2>/dev/null)
grep -qE '^Version:[[:space:]]*2$' <<< "${volcado}" && ok "LUKS2" || mal "no es LUKS2"
[[ "$(grep -cE 'PBKDF:[[:space:]]*argon2id' <<< "${volcado}")" == 2 ]] && ok "argon2id en las dos ranuras" || mal "no es argon2id"
grep -qE '^Flags:[[:space:]].*allow-discards' <<< "${volcado}" && ok "TRIM guardado en la cabecera" || mal "sin allow-discards"
[[ "$(grep -cE '^[[:space:]]+[0-9]+: luks2$' <<< "${volcado}")" == 2 ]] \
  && ok "dos ranuras: contraseña y clave de recuperación" || mal "no hay dos ranuras"
mkfs.ext4 -q "/dev/mapper/${LUKS_NAME}" && mkdir -p "${T}/raiz" && mount "/dev/mapper/${LUKS_NAME}" "${T}/raiz"
[[ "$(luks_uuid_of "${T}/raiz")" == "$(cryptsetup luksUUID "${CIFRADA}")" ]] \
  && ok "luks_uuid_of da el UUID para cryptdevice=" || mal "luks_uuid_of no da el UUID"
[[ -z "$(luks_uuid_of "${T}")" ]] && ok "luks_uuid_of: nada si no está cifrado" || mal "luks_uuid_of ve cifrado lo que no lo está"
umount "${T}/raiz"
tiene "$(problemas "${LIMPIO}")" "volumen cifrado abierto" && ok "con el volumen abierto, el disco se rechaza" \
  || mal "acepta borrar un disco con el volumen cifrado abierto"
close_luks
[[ -b "/dev/mapper/${LUKS_NAME}" ]] && mal "close_luks no lo cierra" || ok "close_luks cierra el que abrió luks_root"
printf '%s' "clave de prueba" | cryptsetup open --key-file=- "${CIFRADA}" "${LUKS_NAME}" 2>/dev/null
close_luks
[[ -b "/dev/mapper/${LUKS_NAME}" ]] && ok "close_luks no cierra uno que ya estaba abierto" \
  || mal "close_luks cierra un volumen que no abrió"
cryptsetup close "${LUKS_NAME}" 2>/dev/null
printf '%s' "clave de prueba" | cryptsetup open --test-passphrase --key-file=- "${CIFRADA}" 2>/dev/null \
  && ok "abre con la contraseña" || mal "no abre con la contraseña"
printf '%s' "${recuperacion}" | cryptsetup open --test-passphrase --key-file=- "${CIFRADA}" 2>/dev/null \
  && ok "abre con la clave de recuperación" || mal "no abre con la clave de recuperación"
printf '%s' "otra clave" | cryptsetup open --test-passphrase --key-file=- "${CIFRADA}" 2>/dev/null \
  && mal "abre con una contraseña mala" || ok "no abre con una contraseña mala"

echo "==> Cifrado: el gancho del initramfs (sin Plymouth: pregunta en la consola)"
# Lo de mkinitcpio que usa el gancho, de mentira; plymouth existe pero no responde (sin splash).
# PATH solo con lo que seguro hay en el initramfs además del busybox reducido de mkinitcpio (que no
# trae tr ni stty): así falla si el gancho empieza a usar algún programa que allí no existe.
INITRAMFS_BIN="${T}/initramfs-bin"
mkdir -p "${INITRAMFS_BIN}"
for p in cryptsetup modprobe sleep; do ln -sf "$(command -v "${p}")" "${INITRAMFS_BIN}/${p}"; done
gancho() {
  local shell=$1
  # shellcheck disable=SC2086  # «busybox ash» son dos palabras
  timeout 120 ${shell} -c '
    PATH=$3
    resolve_device() { echo "$1"; }
    getarg() { :; }
    plymouth() { return 1; }
    . "$1"
    cryptdevice="$2:prueba-cifrado"
    run_hook
  ' gancho "${REPO}/os/initcpio/hooks/command-os-cifrado" "${CIFRADA}" "${INITRAMFS_BIN}" >/dev/null 2>&1
}
conchas=(bash)
command -v busybox >/dev/null && conchas+=("busybox ash")
# Idioma: del parámetro command-os.idioma= de la línea del kernel (lib/apply-boot); castellano si no está.
for concha in "${conchas[@]}"; do
  # shellcheck disable=SC2086
  idiomas=$(${concha} -c '. "$1"; idioma_arranque "quiet command-os.idioma=en splash"; idioma_arranque "quiet splash"
    idioma_arranque "command-os.idioma=fr"; textos_cifrado en; echo "${TEXTO_PEDIR}"; textos_cifrado fr
    echo "${TEXTO_PEDIR}"' _ "${REPO}/os/initcpio/hooks/command-os-cifrado")
  [[ "${idiomas}" == $'en\nes\nfr\nDisk password (or recovery key)\nContraseña del disco (o clave de recuperación)' ]] \
    && ok "${concha}: idioma del gancho por la línea del kernel" || mal "${concha}: idioma del gancho: ${idiomas//$'\n'/ | }"
done
for concha in "${conchas[@]}"; do
  # Una mala y después la clave de recuperación con guiones (como se enseña al instalar) o con espacios.
  for sep in - ' '; do
    agrupada=$(sed -E "s/(.{6})/\\1${sep}/g; s/${sep}\$//" <<< "${recuperacion}")
    printf 'mala\n%s\n' "${agrupada}" | gancho "${concha}"
    if [[ -b /dev/mapper/prueba-cifrado ]]; then
      ok "${concha}: tras una mala, abre con la clave de recuperación separada con «${sep}»"
      cryptsetup close prueba-cifrado
    else
      mal "${concha}: el gancho no abre con la clave separada con «${sep}»"
    fi
  done
done
# Sin poder preguntar (la consola sin entrada), tras 5 intentos lo deja al gancho encrypt: el
# arranque no se queda colgado en el splash.
if gancho bash </dev/null; then
  [[ -b /dev/mapper/prueba-cifrado ]] && mal "abre sin contraseña" || ok "sin poder preguntar, cede el paso a encrypt"
else
  mal "sin poder preguntar, el gancho no termina"
fi
grep -qE '^ +hooks="HOOKS=\(base udev plymouth keyboard autodetect .*keymap block command-os-cifrado encrypt filesystems' \
  "${REPO}/os/install.sh" && ok "install.sh: plymouth, teclado y keymap antes del gancho, y este antes de encrypt" \
  || mal "install.sh: orden de los ganchos del disco cifrado"

echo "==> Entradas viejas de la NVRAM (efibootmgr de mentira)"
FALSO="${T}/falso"
mkdir -p "${FALSO}"
export NVRAM_FALSA="${T}/nvram" NVRAM_BORRADAS="${T}/borradas"
otra=$(blkid -s PARTUUID -o value "$(part_path "${WINDOWS}" 2)")
{
  printf 'BootCurrent: 0001\n'
  printf 'Boot0001* Windows Boot Manager\tHD(1,GPT,%s,0x800,0x82000)/\\EFI\\Microsoft\\Boot\\bootmgfw.efi\n' "${otra}"
  printf 'Boot0002* command-os\tHD(1,GPT,%s,0x800,0x82000)/\\EFI\\command-os\\grubx64.efi\n' "${otra}"
  printf 'Boot0003* command-os\tHD(1,GPT,0badc0de-0000-4000-8000-000000000000,0x800,0x82000)/\\EFI\\command-os\\grubx64.efi\n'
  printf 'Boot0004* command-os-rescate\tHD(1,GPT,0badc0de-0000-4000-8000-000000000001,0x800,0x82000)/\\EFI\\x.efi\n'
} > "${NVRAM_FALSA}"
cat > "${FALSO}/efibootmgr" <<'FAKE'
#!/bin/sh
case " $* " in *" -B "*) echo "$*" >> "${NVRAM_BORRADAS}"; exit 0 ;; esac
cat "${NVRAM_FALSA}"
FAKE
chmod +x "${FALSO}/efibootmgr"
: > "${NVRAM_BORRADAS}"
# Con set -e, como en los instaladores: una entrada que apunta a una partición que no existe no
# puede cerrar el instalador (blkid sale con 2).
( set -e; PATH="${FALSO}:${PATH}" forget_nvram_entries "${LIMPIO}"; touch "${T}/nvram-acabo" )
[[ -f "${T}/nvram-acabo" ]] && ok "con set -e, termina aunque una entrada apunte a una partición que no existe" \
  || mal "forget_nvram_entries cierra el instalador con set -e"
grep -q -- '-b 0003 ' "${NVRAM_BORRADAS}" && ok "borra la entrada que apunta a una partición que ya no existe" \
  || mal "no borra la entrada muerta"
grep -q -- '-b 0002 ' "${NVRAM_BORRADAS}" && mal "borra el Command OS de otro disco" || ok "respeta el Command OS de otro disco"
grep -qE -- '-b 000[14] ' "${NVRAM_BORRADAS}" && mal "borra entradas que no son command-os" || ok "no toca Windows ni otras etiquetas"

echo "==> El instalador entero (se para antes de tocar nada)"
inst() { COMMAND_OS_FUERA_DEL_USB=1 NO_NVRAM=1 bash "${REPO}/build/x86/install-disco.sh" "$@" 2>&1; }
salida=$(env -u COMMAND_OS_FUERA_DEL_USB bash "${REPO}/build/x86/install-disco.sh" "${LIMPIO}" 2>&1 </dev/null)
tiene "${salida}" "USB en vivo" && ok "fuera del USB en vivo no hace nada" || mal "corre fuera del USB en vivo"
salida=$(inst "${MONTADO}" </dev/null)
tiene "${salida}" "No se puede instalar" && ok "rechaza el disco montado" || mal "no rechaza el disco montado"
huella_limpio=$(sha256sum < "${LIMPIO}")
salida=$(inst "${LIMPIO}" <<< "no")
tiene "${salida}" "cancelado: no se ha tocado nada" && ok "una confirmación mala cancela" || mal "no cancela con una confirmación mala"
[[ "$(sha256sum < "${LIMPIO}")" == "${huella_limpio}" ]] && ok "y el disco queda igual" || mal "tocó el disco sin confirmar"

[[ "$(sha256sum < "${SENUELO}")" == "${huella_senuelo}" ]] && ok "el disco señuelo no se ha tocado" || mal "SE TOCÓ EL DISCO SEÑUELO"

echo
if (( fallos )); then echo "==> ${fallos} fallo(s)"; exit 1; fi
echo "==> Todo correcto"
