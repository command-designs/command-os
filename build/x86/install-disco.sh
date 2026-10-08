#!/usr/bin/env bash
# Instala Command OS como sistema principal de un PC x86_64: BORRA EL DISCO ENTERO (Windows, otros
# sistemas y datos incluidos). Se ejecuta como root desde el USB en vivo de Arch Linux (pasos en
# docs/instalacion.md); lo más cómodo es el asistente build/x86/instalar.sh, que lo llama:
#   bash build/x86/install-disco.sh /dev/nvme0n1
# Deja GPT con una partición EFI de 1 GiB y el resto en btrfs con instantáneas (build/x86/lib.sh),
# GRUB con su entrada en la NVRAM y el arranque de reserva EFI/BOOT/BOOTX64.EFI. Con el disco
# cifrado (lo pregunta, sí por defecto): EFI, /boot de 1 GiB sin cifrar y el resto en LUKS2.
#
# Antes de tocar nada comprueba el disco (lib.sh: disk_problems): nunca borra el USB en vivo, el
# disco del sistema en marcha, uno con particiones montadas, swap o volúmenes en uso, ni uno de solo
# lectura; enseña lo que hay y pide escribir el nombre exacto del disco (y BORRAR WINDOWS si lo tiene).
#
# Variables: COMMAND_OS_IDIOMA (es|en, mensajes e idioma del sistema; default es), KB_LAYOUT
# (teclado; default es, o us en inglés), TIMEZONE (default Europe/Madrid, o UTC en inglés: la zona
# se elige luego en el asistente de primer arranque), HOSTNAME_NEW (default command-os), VARIANT (auto: pc-nvidia si hay GPU NVIDIA), MIN_GB (disco mínimo, 30),
# CIFRADO=si|no (no pregunta si cifrar; la contraseña y la clave de recuperación se piden siempre),
# ROLLING=1 (Arch del día en vez de la fecha validada). Solo para pruebas en una VM: NO_NVRAM=1
# (no registra la entrada UEFI), COMMAND_OS_SSH=1 (servidor SSH encendido), COMMAND_OS_FUERA_DEL_USB=1
# (deja ejecutarlo fuera del USB en vivo; tests/discos.sh).
set -euo pipefail

REPO=$(cd "$(dirname "$0")/../.." && pwd)
source "${REPO}/build/x86/lib.sh"
cargar_idioma
DISK=${1:-}
KB_LAYOUT=${KB_LAYOUT:-${KB_DEFECTO}}
HOSTNAME_NEW=${HOSTNAME_NEW:-command-os}
MNT=/mnt/command-os

die() { echo "error: $*" >&2; exit 1; }
cleanup() { set +e; mountpoint -q "$MNT" && umount -R "$MNT"; close_luks; }
trap cleanup EXIT

[[ $(id -u) -eq 0 ]] || die "$(t 'ejecutar como root')"
require_live_usb
[[ -n "$DISK" ]] || die "$(t 'uso: %s /dev/<disco>   (ver discos con: lsblk -do NAME,SIZE,MODEL)' "$0")"
[[ -n "${NO_NVRAM:-}" || -d /sys/firmware/efi ]] \
  || die "$(t 'el USB no arrancó en modo UEFI (desactiva CSM/Legacy en la BIOS)')"

problems=$(disk_problems "$DISK")
if [[ -n "$problems" ]]; then
  echo "$(t 'No se puede instalar en %s:' "$DISK")" >&2
  sed 's/^/  - /' <<< "$problems" >&2
  exit 1
fi

# Cifrado, contraseña y clave de recuperación: todo antes de la confirmación del borrado.
prepare_encryption

echo
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MODEL,SERIAL "$DISK"
echo
echo "$(t 'SE VA A BORRAR TODO EL DISCO %s (%s, %s).' "$DISK" "$(lsblk -dno SIZE "$DISK" | tr -d ' ')" "$(lsblk -dno MODEL "$DISK" | xargs)")"
echo "$(t 'Todo lo que contiene (sistemas, particiones y archivos) se pierde y no se puede recuperar.')"
if disk_has_windows "$DISK"; then
  echo "$(t 'Este disco tiene WINDOWS. Si quieres conservarlo, cancela y usa el dual boot (docs/dualboot.md).')"
fi
confirm_erase "$DISK" || die "$(t 'cancelado: no se ha tocado nada')"

pacman -Sy --needed --noconfirm arch-install-scripts gptfdisk dosfstools btrfs-progs cryptsetup >/dev/null
echo "==> $(t 'Particiones')"
ESP=$(part_path "$DISK" 1)
mkdir -p "$MNT"
if [[ "$CIFRADO" == si ]]; then
  partition_whole_disk "$DISK" cifrado
  BOOT=$(part_path "$DISK" 2)
  ROOT=$(part_path "$DISK" 3)
  mkfs.fat -F32 -n EFI "$ESP" >/dev/null
  echo "==> $(t 'Cifrando el disco (LUKS2)')"
  luks_root "$ROOT"
  btrfs_root "/dev/mapper/$LUKS_NAME" "$MNT"
  boot_partition "$BOOT" "$MNT"
else
  partition_whole_disk "$DISK"
  ROOT=$(part_path "$DISK" 2)
  mkfs.fat -F32 -n EFI "$ESP" >/dev/null
  btrfs_root "$ROOT" "$MNT"
fi
mkdir -p "$MNT/efi"
mount "$ESP" "$MNT/efi"

detect_variant
install_base "$MNT" "$REPO"
configure_system "$MNT" propia "$DISK"

sync
echo
echo "==> $(t 'Command OS instalado en %s.' "$DISK")"
[[ "$CIFRADO" == si ]] && echo "    $(t 'Disco cifrado: al encender, escribe su contraseña en la pantalla de arranque.')"
echo "    $(t 'Quita el USB y reinicia (reboot): el asistente de primer arranque te pide crear tu cuenta.')"
