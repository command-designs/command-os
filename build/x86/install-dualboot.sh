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
# NO_NVRAM=1 (no registra la entrada UEFI; solo para pruebas sobre un disco loop),
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

if [[ -z "${VARIANT+x}" ]]; then
  VARIANT=
  lspci 2>/dev/null | grep -qiE '(vga|3d|display).*nvidia' && VARIANT=pc-nvidia
fi
echo "==> Variante: ${VARIANT:-ninguna (GPU Intel/AMD)}"

# El kernel y el initramfs van en /boot dentro de btrfs (entran en las instantáneas): la EFI de
# Windows suele ser de 100-300 MB y solo recibe el binario de GRUB (EFI/command-os/grubx64.efi).
pacstrap -K -C "$(pinned_pacman_conf "$REPO")" "$MNT" base linux linux-firmware intel-ucode \
  amd-ucode sudo networkmanager openssh grub efibootmgr ntfs-3g btrfs-progs git base-devel
# Sin swap (genfstab copiaría la del sistema en vivo) y sin subvolid (ver build/x86/lib.sh).
fstab "$MNT"

mkdir -p "$MNT/root/command-os-src" "$MNT/etc/command-os"
cp -r "$REPO/os" "$MNT/root/command-os-src/os"
find "$MNT/root/command-os-src/os" -name '*.sh' -exec sed -i 's/\r$//' {} +
touch "$MNT/etc/command-os/dualboot"
echo "$KB_LAYOUT" > "$MNT/etc/command-os/kb_layout"
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

NVRAM_FLAG=
[[ -n "${NO_NVRAM:-}" ]] && NVRAM_FLAG=--no-nvram
arch-chroot "$MNT" /bin/bash -euxc "
  ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
  echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
  echo 'es_ES.UTF-8 UTF-8' >> /etc/locale.gen
  locale-gen
  echo 'LANG=en_US.UTF-8' > /etc/locale.conf
  echo 'KEYMAP=${KB_LAYOUT}' > /etc/vconsole.conf
  echo ${HOSTNAME_NEW} > /etc/hostname
  passwd -l root
  COMMAND_OS_VARIANT=${VARIANT} bash /root/command-os-src/os/install.sh
  if [[ '${VARIANT}' == pc-nvidia ]]; then
    grep -q 'nvidia_drm.modeset' /etc/default/grub || sed -i -E 's/^(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*)\"/\1 nvidia_drm.modeset=1 nvidia_drm.fbdev=1\"/' /etc/default/grub
  fi
  # Sin --removable: no se pisa EFI/BOOT/BOOTX64.EFI (el arranque de reserva de Windows).
  grub-install --target=x86_64-efi --efi-directory=/efi --boot-directory=/boot --bootloader-id=command-os ${NVRAM_FLAG}
  grub-mkconfig -o /boot/grub/grub.cfg
"
rm -rf "$MNT/root/command-os-src"

if grep -q "menuentry 'Windows" "$MNT/boot/grub/grub.cfg"; then
  echo "==> GRUB tiene entrada para Windows"
else
  echo "aviso: GRUB no tiene entrada de Windows (sigue en el menú de arranque de la BIOS)" >&2
fi

sync
echo
echo "==> Command OS instalado en $ROOT."
echo "    Usuario deck / contraseña deck: cámbiala con 'passwd' al entrar."
echo "    Quita el USB y reinicia: sale el menú de GRUB (Command OS / Windows)."
