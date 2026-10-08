#!/usr/bin/env bash
# Instala Command OS en un PC x86_64 junto a Windows (dual boot UEFI). Se ejecuta como root
# desde el USB en vivo de Arch Linux, con el espacio ya liberado en Windows (pasos en
# docs/dualboot.md):
#   bash build/x86/install-dualboot.sh /dev/nvme0n1
# Crea una partición btrfs (con instantáneas, build/x86/lib.sh) en el mayor hueco libre del
# disco, reutiliza la partición EFI de Windows sin formatearla y deja GRUB con menú
# (Command OS / Windows). No toca ninguna partición existente. Con el disco cifrado (lo pregunta,
# sí por defecto), en el hueco van dos: /boot de 1 GiB sin cifrar y el resto en LUKS2.
# CIFRADO=si|no no pregunta si cifrar (la contraseña y la clave de recuperación se piden siempre).
# Variables: COMMAND_OS_IDIOMA (es|en, mensajes e idioma del sistema; default es), KB_LAYOUT
# (teclado; default es, o us en inglés), TIMEZONE (default Europe/Madrid, o UTC en inglés: la zona
# se elige luego en el asistente de primer arranque), HOSTNAME_NEW (default command-os), VARIANT (auto: pc-nvidia si hay GPU NVIDIA), MIN_GB (hueco mínimo, 30),
# NO_NVRAM=1 (no registra la entrada UEFI; solo para pruebas sobre un disco loop, junto con
# COMMAND_OS_FUERA_DEL_USB=1, que deja ejecutarlo fuera del USB en vivo),
# ROLLING=1 (Arch del día en vez de la fecha validada).
set -euo pipefail

REPO=$(cd "$(dirname "$0")/../.." && pwd)
source "${REPO}/build/x86/lib.sh"
cargar_idioma
DISK=${1:-}
KB_LAYOUT=${KB_LAYOUT:-${KB_DEFECTO}}
HOSTNAME_NEW=${HOSTNAME_NEW:-command-os}
MIN_GB=${MIN_GB:-30}
MNT=/mnt/command-os
ESP_GUID=c12a7328-f81f-11d2-ba4b-00a0c93ec93b

die() { echo "error: $*" >&2; exit 1; }
cleanup() { set +e; mountpoint -q "$MNT" && umount -R "$MNT"; close_luks; }
trap cleanup EXIT

[[ $(id -u) -eq 0 ]] || die "$(t 'ejecutar como root')"
require_live_usb
[[ -b "$DISK" ]] || die "$(t 'uso: %s /dev/<disco>   (ver discos con: lsblk -o NAME,SIZE,MODEL)' "$0")"
[[ -n "${NO_NVRAM:-}" || -d /sys/firmware/efi ]] \
  || die "$(t 'el USB no arrancó en modo UEFI (desactiva CSM/Legacy en la BIOS)')"
[[ $(lsblk -dno PTTYPE "$DISK") == gpt ]] || die "$(t '%s no es GPT (Windows en UEFI siempre usa GPT)' "$DISK")"

pacman -Sy --needed --noconfirm arch-install-scripts gptfdisk dosfstools btrfs-progs cryptsetup >/dev/null

# Tabla de particiones leída con sfdisk (no depende de udev, a diferencia de lsblk PARTTYPE).
parts() { sfdisk -d "$DISK" | grep '^/dev/'; }

# Partición EFI existente (la de Windows): se comparte, no se formatea.
ESP=$(parts | grep -i "type=$ESP_GUID" | head -1 | cut -d' ' -f1)
[[ -n "$ESP" ]] || die "$(t 'no hay partición EFI en %s' "$DISK")"

# Mayor hueco libre del disco (el que se liberó al encoger C: en Windows).
FREE_SECTORS=$(sfdisk --list-free "$DISK" \
  | awk '$1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ {print $3}' | sort -n | tail -1)
SECTOR=$(blockdev --getss "$DISK")
FREE_GB=$(( ${FREE_SECTORS:-0} * SECTOR / 1024 / 1024 / 1024 ))
(( FREE_GB >= MIN_GB )) || die "$(t 'solo hay %s GB libres sin particionar en %s (mínimo %s); encoge C: en Windows primero' "${FREE_GB}" "$DISK" "${MIN_GB}")"

# Cifrado, contraseña y clave de recuperación: todo antes de la confirmación.
prepare_encryption
# Cifrado, /boot ocupa 1 GiB del hueco: el sistema tiene que seguir teniendo el mínimo.
if [[ "$CIFRADO" == si ]] && (( FREE_GB < MIN_GB + 1 )); then
  die "$(t 'con el disco cifrado hacen falta %s GB libres (1 para /boot); hay %s' "$(( MIN_GB + 1 ))" "${FREE_GB}")"
fi

echo
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL "$DISK"
echo
if [[ "$CIFRADO" == si ]]; then
  parrafo "$(t 'Se crearán dos particiones en el espacio libre de %s (%s GB): /boot de 1 GB y el resto cifrado. Se añadirá GRUB a la partición EFI %s. Windows y sus particiones no se tocan.' "$DISK" "${FREE_GB}" "$ESP")"
else
  parrafo "$(t 'Se creará una partición nueva de %s GB en el espacio libre de %s y se añadirá GRUB a la partición EFI %s. Windows y sus particiones no se tocan.' "${FREE_GB}" "$DISK" "$ESP")"
fi
confirmar_si || die "$(t 'cancelado')"

# new_partition TAMAÑO TIPO NOMBRE — crea una partición al principio del mayor hueco libre (inicio
# 0 = ese hueco; TAMAÑO 0 = hasta su final) e imprime su ruta.
new_partition() {
  local before dev
  before=$(parts | cut -d' ' -f1 | sort)
  sgdisk -n "0:0:$1" -t "0:$2" -c "0:$3" "$DISK" >/dev/null
  partprobe "$DISK"; udevadm settle 2>/dev/null || sleep 2
  dev=$(comm -13 <(echo "$before") <(parts | cut -d' ' -f1 | sort) | head -1)
  [[ -b "$dev" ]] || die "$(t 'no se encontró la partición nueva')"
  echo "$dev"
}

mkdir -p "$MNT"
if [[ "$CIFRADO" == si ]]; then
  # /boot sin cifrar (8300; GRUB lee de aquí el kernel) y el resto en LUKS (8309).
  BOOT=$(new_partition +1G 8300 command-os-boot)
  ROOT=$(new_partition 0 8309 command-os)
  echo "==> $(t 'Particiones nuevas: %s (/boot) y %s (cifrada)' "$BOOT" "$ROOT")"
  echo "==> $(t 'Cifrando la partición (LUKS2)')"
  luks_root "$ROOT"
  btrfs_root "/dev/mapper/$LUKS_NAME" "$MNT"
  boot_partition "$BOOT" "$MNT"
else
  # Tipo 8304 = raíz Linux x86-64.
  ROOT=$(new_partition 0 8304 command-os)
  echo "==> $(t 'Partición nueva: %s' "$ROOT")"
  btrfs_root "$ROOT" "$MNT"
fi
mkdir -p "$MNT/efi"
mount "$ESP" "$MNT/efi"
ESP_FREE_MB=$(( $(df --output=avail -k "$MNT/efi" | tail -1) / 1024 ))
(( ESP_FREE_MB >= 10 )) || die "$(t 'la partición EFI solo tiene %s MB libres' "${ESP_FREE_MB}")"

detect_variant

# La EFI de Windows suele ser de 100-300 MB: solo recibe el binario de GRUB
# (EFI/command-os/grubx64.efi); el kernel va en /boot dentro de btrfs o, cifrado, en la partición
# /boot nueva (build/x86/lib.sh).
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
  echo "$(t 'aviso: no hay EFI/Microsoft/Boot/bootmgfw.efi en %s; GRUB no tendrá entrada de Windows' "$ESP")" >&2
fi

# Sin --removable: no se pisa EFI/BOOT/BOOTX64.EFI (el arranque de reserva de Windows).
configure_system "$MNT" compartida "$DISK"

if grep -q "menuentry 'Windows" "$MNT/boot/grub/grub.cfg"; then
  echo "==> $(t 'GRUB tiene entrada para Windows')"
else
  echo "$(t 'aviso: GRUB no tiene entrada de Windows (sigue en el menú de arranque de la BIOS)')" >&2
fi

sync
echo
echo "==> $(t 'Command OS instalado en %s.' "$ROOT")"
[[ "$CIFRADO" == si ]] && echo "    $(t 'Disco cifrado: al encender, escribe su contraseña en la pantalla de arranque.')"
echo "    $(t 'Al encender, el asistente de primer arranque te pide crear tu cuenta.')"
echo "    $(t 'Quita el USB y reinicia: sale el menú de GRUB (Command OS / Windows).')"
