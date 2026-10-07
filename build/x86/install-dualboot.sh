#!/usr/bin/env bash
# Instala Command OS en un PC x86_64 junto a Windows (dual boot UEFI). Se ejecuta como root
# desde el USB en vivo de Arch Linux, con el espacio ya liberado en Windows (pasos en
# docs/dualboot.md):
#   bash build/x86/install-dualboot.sh /dev/nvme0n1
# Crea una partición btrfs (con instantáneas, build/x86/lib.sh) en el mayor hueco libre del
# disco, reutiliza la partición EFI de Windows sin formatearla y deja GRUB con menú
# (Command OS / Windows). No toca ninguna partición existente.
# Variables: KB_LAYOUT (teclado, default es), TIMEZONE (default Europe/Madrid), HOSTNAME_NEW
# (default command-os), VARIANT (auto: pc-nvidia si hay GPU NVIDIA), MIN_GB (hueco mínimo, 30),
# NO_NVRAM=1 (no registra la entrada UEFI; solo para pruebas sobre un disco loop, junto con
# COMMAND_OS_FUERA_DEL_USB=1, que deja ejecutarlo fuera del USB en vivo),
# ROLLING=1 (Arch del día en vez de la fecha validada).
set -euo pipefail

REPO=$(cd "$(dirname "$0")/../.." && pwd)
source "${REPO}/build/x86/lib.sh"
DISK=${1:-}
KB_LAYOUT=${KB_LAYOUT:-es}
TIMEZONE=${TIMEZONE:-Europe/Madrid}
HOSTNAME_NEW=${HOSTNAME_NEW:-command-os}
MIN_GB=${MIN_GB:-30}
MNT=/mnt/command-os
ESP_GUID=c12a7328-f81f-11d2-ba4b-00a0c93ec93b

die() { echo "error: $*" >&2; exit 1; }
cleanup() { set +e; mountpoint -q "$MNT" && umount -R "$MNT"; }
trap cleanup EXIT

[[ $(id -u) -eq 0 ]] || die "ejecutar como root"
require_live_usb
[[ -b "$DISK" ]] || die "uso: $0 /dev/<disco>   (ver discos con: lsblk -o NAME,SIZE,MODEL)"
[[ -n "${NO_NVRAM:-}" || -d /sys/firmware/efi ]] \
  || die "el USB no arrancó en modo UEFI (desactiva CSM/Legacy en la BIOS)"
[[ $(lsblk -dno PTTYPE "$DISK") == gpt ]] || die "$DISK no es GPT (Windows en UEFI siempre usa GPT)"

pacman -Sy --needed --noconfirm arch-install-scripts gptfdisk dosfstools btrfs-progs >/dev/null

# Tabla de particiones leída con sfdisk (no depende de udev, a diferencia de lsblk PARTTYPE).
parts() { sfdisk -d "$DISK" | grep '^/dev/'; }

# Partición EFI existente (la de Windows): se comparte, no se formatea.
ESP=$(parts | grep -i "type=$ESP_GUID" | head -1 | cut -d' ' -f1)
[[ -n "$ESP" ]] || die "no hay partición EFI en $DISK"

# Mayor hueco libre del disco (el que se liberó al encoger C: en Windows).
FREE_SECTORS=$(sfdisk --list-free "$DISK" \
  | awk '$1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ {print $3}' | sort -n | tail -1)
SECTOR=$(blockdev --getss "$DISK")
FREE_GB=$(( ${FREE_SECTORS:-0} * SECTOR / 1024 / 1024 / 1024 ))
(( FREE_GB >= MIN_GB )) || die "solo hay ${FREE_GB} GB libres sin particionar en $DISK (mínimo ${MIN_GB}); encoge C: en Windows primero"

echo
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL "$DISK"
echo
echo "Se creará una partición nueva de ${FREE_GB} GB en el espacio libre de $DISK"
echo "y se añadirá GRUB a la partición EFI $ESP. Windows y sus particiones no se tocan."
read -rp "Escribe SI para continuar: " ok
[[ "$ok" == SI ]] || die "cancelado"

# Partición nueva: inicio y fin 0 = el mayor bloque libre. Tipo 8304 = raíz Linux x86-64.
before=$(parts | cut -d' ' -f1 | sort)
sgdisk -n 0:0:0 -t 0:8304 -c 0:command-os "$DISK"
partprobe "$DISK"; udevadm settle 2>/dev/null || sleep 2
ROOT=$(comm -13 <(echo "$before") <(parts | cut -d' ' -f1 | sort) | head -1)
[[ -b "$ROOT" ]] || die "no se encontró la partición nueva"
echo "==> Partición nueva: $ROOT"

mkdir -p "$MNT"
btrfs_root "$ROOT" "$MNT"
mkdir -p "$MNT/efi"
mount "$ESP" "$MNT/efi"
ESP_FREE_MB=$(( $(df --output=avail -k "$MNT/efi" | tail -1) / 1024 ))
(( ESP_FREE_MB >= 10 )) || die "la partición EFI solo tiene ${ESP_FREE_MB} MB libres"

detect_variant

# La EFI de Windows suele ser de 100-300 MB: solo recibe el binario de GRUB
# (EFI/command-os/grubx64.efi); el kernel va en /boot dentro de btrfs (build/x86/lib.sh).
install_base "$MNT" "$REPO" ntfs-3g
touch "$MNT/etc/command-os/dualboot"
# Windows guarda la hora local en el reloj del equipo: Linux también, para que no se desfase.
printf '0.0 0 0.0\n0\nLOCAL\n' > "$MNT/etc/adjtime"

# Entrada fija de Windows en GRUB (en vez de os-prober, que depende de udev y no siempre lo
# detecta): arranca el gestor de Windows desde la partición EFI, buscada por UUID.
ESP_UUID=$(blkid -s UUID -o value "$ESP")
if [[ -e "$MNT/efi/EFI/Microsoft/Boot/bootmgfw.efi" ]]; then
  cat > "$MNT/etc/grub.d/35_command-os-windows" <<EOF
#!/bin/sh
exec tail -n +3 \$0
menuentry 'Windows' --class windows --class os {
	insmod part_gpt
	insmod fat
	search --no-floppy --fs-uuid --set=root ${ESP_UUID}
	chainloader /EFI/Microsoft/Boot/bootmgfw.efi
}
EOF
  chmod 755 "$MNT/etc/grub.d/35_command-os-windows"
else
  echo "aviso: no hay EFI/Microsoft/Boot/bootmgfw.efi en $ESP; GRUB no tendrá entrada de Windows" >&2
fi

# Sin --removable: no se pisa EFI/BOOT/BOOTX64.EFI (el arranque de reserva de Windows).
configure_system "$MNT" compartida "$DISK"

if grep -q "menuentry 'Windows" "$MNT/boot/grub/grub.cfg"; then
  echo "==> GRUB tiene entrada para Windows"
else
  echo "aviso: GRUB no tiene entrada de Windows (sigue en el menú de arranque de la BIOS)" >&2
fi

sync
echo
echo "==> Command OS instalado en $ROOT."
echo "    Al encender, el asistente de primer arranque te pide crear tu cuenta."
echo "    Quita el USB y reinicia: sale el menú de GRUB (Command OS / Windows)."
