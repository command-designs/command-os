#!/usr/bin/env bash
# Command OS — prueba de la seguridad del instalador en disco entero (build/x86/lib.sh e
# install-disco.sh): qué discos rechaza, la confirmación, el particionado y que nunca toca otro
# disco. Solo con discos loop sobre archivos temporales: no mira ni toca ningún disco real.
#
# Necesita root, losetup, sgdisk (gdisk), mkfs.fat (dosfstools) y mkntfs (ntfs-3g). Lo ejecuta
# GitHub Actions en ubuntu-latest (.github/workflows/pruebas.yml). Sale con 1 si algo falla.
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
  umount -q "${T}/montado" 2>/dev/null
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
PATH="${FALSO}:${PATH}" forget_nvram_entries "${LIMPIO}"
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
