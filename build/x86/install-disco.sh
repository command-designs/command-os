#!/usr/bin/env bash
# Instala Command OS como sistema principal de un PC x86_64: BORRA EL DISCO ENTERO (Windows, otros
# sistemas y datos incluidos). Se ejecuta como root desde el USB en vivo de Arch Linux (pasos en
# docs/instalacion.md); lo más cómodo es el asistente build/x86/instalar.sh, que lo llama:
#   bash build/x86/install-disco.sh /dev/nvme0n1
# Deja GPT con una partición EFI de 1 GiB y el resto en btrfs con instantáneas (build/x86/lib.sh),
# GRUB con su entrada en la NVRAM y el arranque de reserva EFI/BOOT/BOOTX64.EFI.
#
# Antes de tocar nada comprueba el disco (lib.sh: disk_problems): nunca borra el USB en vivo, el
# disco del sistema en marcha, uno con particiones montadas, swap o volúmenes en uso, ni uno de solo
# lectura; enseña lo que hay y pide escribir el nombre exacto del disco (y BORRAR WINDOWS si lo tiene).
#
# Variables: KB_LAYOUT (teclado, default es), TIMEZONE (default Europe/Madrid), HOSTNAME_NEW
# (default command-os), VARIANT (auto: pc-nvidia si hay GPU NVIDIA), MIN_GB (disco mínimo, 30),
# ROLLING=1 (Arch del día en vez de la fecha validada). Solo para pruebas en una VM: NO_NVRAM=1
# (no registra la entrada UEFI), COMMAND_OS_SSH=1 (servidor SSH encendido).
set -euo pipefail

REPO=$(cd "$(dirname "$0")/../.." && pwd)
source "${REPO}/build/x86/lib.sh"
DISK=${1:-}
KB_LAYOUT=${KB_LAYOUT:-es}
TIMEZONE=${TIMEZONE:-Europe/Madrid}
HOSTNAME_NEW=${HOSTNAME_NEW:-command-os}
MNT=/mnt/command-os

die() { echo "error: $*" >&2; exit 1; }
cleanup() { set +e; mountpoint -q "$MNT" && umount -R "$MNT"; }
trap cleanup EXIT

[[ $(id -u) -eq 0 ]] || die "ejecutar como root"
require_live_usb
[[ -n "$DISK" ]] || die "uso: $0 /dev/<disco>   (ver discos con: lsblk -do NAME,SIZE,MODEL)"
[[ -n "${NO_NVRAM:-}" || -d /sys/firmware/efi ]] \
  || die "el USB no arrancó en modo UEFI (desactiva CSM/Legacy en la BIOS)"

problems=$(disk_problems "$DISK")
if [[ -n "$problems" ]]; then
  echo "No se puede instalar en $DISK:" >&2
  sed 's/^/  - /' <<< "$problems" >&2
  exit 1
fi

echo
lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,MODEL,SERIAL "$DISK"
echo
echo "SE VA A BORRAR TODO EL DISCO $DISK ($(lsblk -dno SIZE "$DISK" | tr -d ' '), $(lsblk -dno MODEL "$DISK" | xargs))."
echo "Todo lo que contiene (sistemas, particiones y archivos) se pierde y no se puede recuperar."
if disk_has_windows "$DISK"; then
  echo "Este disco tiene WINDOWS. Si quieres conservarlo, cancela y usa el dual boot (docs/dualboot.md)."
fi
confirm_erase "$DISK" || die "cancelado: no se ha tocado nada"

pacman -Sy --needed --noconfirm arch-install-scripts gptfdisk dosfstools btrfs-progs >/dev/null
echo "==> Particiones"
partition_whole_disk "$DISK"
ESP=$(part_path "$DISK" 1)
ROOT=$(part_path "$DISK" 2)
mkfs.fat -F32 -n EFI "$ESP" >/dev/null
mkdir -p "$MNT"
btrfs_root "$ROOT" "$MNT"
mkdir -p "$MNT/efi"
mount "$ESP" "$MNT/efi"

detect_variant
install_base "$MNT" "$REPO"
configure_system "$MNT" propia

sync
echo
echo "==> Command OS instalado en $DISK."
echo "    Quita el USB y reinicia (reboot): el asistente de primer arranque te pide crear tu cuenta."
