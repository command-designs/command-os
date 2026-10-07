#!/usr/bin/env bash
# Construye una imagen de disco raw (UEFI, GPT) de Command OS para PC x86_64,
# grabable en un USB con dd. Correr como root dentro de WSL (Arch):
#   wsl -d archlinux -u root -- bash /mnt/c/<repo>/build/x86/build-image.sh
# Variables: IMG (ruta de salida), SIZE (tamaño sparse), VARIANT (variante de
# os/variants/, default pc-nvidia), DEV_SSH_PUBKEY (fichero .pub opcional: se
# crea la cuenta de desarrollo deck/deck con su llave en ~deck/.ssh y enciende SSH, solo para
# pruebas en VM; sin ella, la imagen es la de producto: el primer arranque pide la cuenta),
# ROLLING=1 (Arch del día en vez de la fecha validada).
# Raíz en btrfs con instantáneas (build/x86/lib.sh) y partición EFI en /efi.
set -euo pipefail

REPO=$(cd "$(dirname "$0")/../.." && pwd)
source "${REPO}/build/x86/lib.sh"
IMG=${IMG:-/root/vm/command-os-x86.img}
SIZE=${SIZE:-14G}
VARIANT=${VARIANT:-pc-nvidia}
MNT=/mnt/command-os-build
LOOP=

cleanup() {
  set +e
  mountpoint -q "$MNT" && umount -R "$MNT"
  [[ -n "$LOOP" ]] && losetup -d "$LOOP"
}
trap cleanup EXIT

[[ $(id -u) -eq 0 ]] || { echo "correr como root" >&2; exit 1; }
pacman -S --needed --noconfirm arch-install-scripts parted dosfstools btrfs-progs >/dev/null

mkdir -p "$(dirname "$IMG")" "$MNT"
rm -f "$IMG"
truncate -s "$SIZE" "$IMG"
LOOP=$(losetup --find --show --partscan "$IMG")

parted -s "$LOOP" mklabel gpt
parted -s "$LOOP" mkpart ESP fat32 1MiB 1025MiB
parted -s "$LOOP" set 1 esp on
parted -s "$LOOP" mkpart root btrfs 1025MiB 100%
partprobe "$LOOP"; udevadm settle 2>/dev/null || sleep 2

mkfs.fat -F32 "${LOOP}p1"
btrfs_root "${LOOP}p2" "$MNT"
mkdir -p "$MNT/efi"
mount "${LOOP}p1" "$MNT/efi"

pacstrap -cK -C "$(pinned_pacman_conf "$REPO")" "$MNT" base linux linux-firmware intel-ucode \
  amd-ucode sudo networkmanager openssh grub efibootmgr btrfs-progs git base-devel
fstab "$MNT"

mkdir -p "$MNT/root/command-os-src"
cp -r "$REPO/os" "$MNT/root/command-os-src/os"
find "$MNT/root/command-os-src/os" -name '*.sh' -exec sed -i 's/\r$//' {} +

arch-chroot "$MNT" /bin/bash -euxc "
  ln -sf /usr/share/zoneinfo/UTC /etc/localtime
  # Castellano de serie; inglés generado para poder elegirlo en el asistente (command-os-idioma).
  echo 'es_ES.UTF-8 UTF-8' >> /etc/locale.gen
  echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
  locale-gen
  echo 'LANG=${IDIOMA}' > /etc/locale.conf
  echo command-os > /etc/hostname
  passwd -l root
  # Imagen para cualquier equipo: GRUB sin la resolución de la máquina que la construye.
  COMMAND_OS_PANTALLA=generica COMMAND_OS_VARIANT=${VARIANT} COMMAND_OS_SSH=${DEV_SSH_PUBKEY:+1} COMMAND_OS_DEV_USER=${DEV_SSH_PUBKEY:+deck} bash /root/command-os-src/os/install.sh
  # install.sh ya dejó el arranque silencioso en la línea del kernel: aquí solo se añade NVIDIA.
  grep -q 'nvidia_drm.modeset' /etc/default/grub || sed -i -E 's/^(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*)\"/\1 nvidia_drm.modeset=1 nvidia_drm.fbdev=1\"/' /etc/default/grub
  # --removable: EFI/BOOT/BOOTX64.EFI, sin depender de la NVRAM del equipo. El kernel y la
  # configuración de GRUB van en /boot dentro de btrfs (entran en las instantáneas).
  grub-install --target=x86_64-efi --efi-directory=/efi --boot-directory=/boot --removable --no-nvram
  LANG=${IDIOMA} grub-mkconfig -o /boot/grub/grub.cfg
"
# Comprobación explícita: una imagen a medias no debe darse por buena aunque algún paso no
# propague su error.
[[ -f "$MNT/usr/share/command-os/version" && -f "$MNT/boot/grub/grub.cfg" \
  && -f "$MNT/efi/EFI/BOOT/BOOTX64.EFI" ]] \
  || { echo "error: la instalación no se completó (ver el registro de arriba)" >&2; exit 1; }

if [[ -n "${DEV_SSH_PUBKEY:-}" ]]; then
  install -d -m 700 -o 1000 -g 1000 "$MNT/home/deck/.ssh"
  install -m 600 -o 1000 -g 1000 "$DEV_SSH_PUBKEY" "$MNT/home/deck/.ssh/authorized_keys"
fi
rm -rf "$MNT/root/command-os-src"

sync
echo "==> Imagen lista: $IMG"
