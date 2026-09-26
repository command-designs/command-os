#!/usr/bin/env bash
# Runs inside the Arch live ISO (over SSH, as root) to lay down a base
# Arch Linux install on the VM's first disk, then reboots into it.
set -euxo pipefail

DISK=/dev/sda
ROOT_PASSWORD=packer
HOSTNAME=command-os-dev

timedatectl set-ntp true

parted -s "${DISK}" mklabel gpt
parted -s "${DISK}" mkpart ESP fat32 1MiB 513MiB
parted -s "${DISK}" set 1 esp on
parted -s "${DISK}" mkpart primary ext4 513MiB 100%

mkfs.fat -F32 "${DISK}1"
mkfs.ext4 -F "${DISK}2"

mount "${DISK}2" /mnt
mkdir -p /mnt/boot
mount "${DISK}1" /mnt/boot

reflector --latest 10 --sort rate --save /etc/pacman.d/mirrorlist || true

pacstrap -K /mnt base linux linux-firmware sudo networkmanager openssh \
  grub efibootmgr vim git base-devel

genfstab -U /mnt >> /mnt/etc/fstab

arch-chroot /mnt /bin/bash -euxc "
  ln -sf /usr/share/zoneinfo/UTC /etc/localtime
  hwclock --systohc
  echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
  locale-gen
  echo 'LANG=en_US.UTF-8' > /etc/locale.conf
  echo '${HOSTNAME}' > /etc/hostname
  echo 'root:${ROOT_PASSWORD}' | chpasswd
  sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
  systemctl enable NetworkManager.service
  systemctl enable sshd.service
  grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
  grub-mkconfig -o /boot/grub/grub.cfg
"

umount -R /mnt
(sleep 2 && reboot) &
exit 0
