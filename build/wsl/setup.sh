#!/bin/sh
# Prepara el anfitrión WSL2 (Arch) para correr la VM de desarrollo con KVM +
# aceleración 3D. Correr como root dentro de WSL:
#   wsl -d archlinux -u root -- sh /mnt/c/<ruta al repo>/build/wsl/setup.sh
# Copia el disco al filesystem de WSL (/root/vm) porque correr desde /mnt/c es
# lento. Re-correrlo sobreescribe la copia de /root/vm con la de Windows.
set -e
REPO=$(cd "$(dirname "$0")/../.." && pwd)
VM=/root/vm

[ -c /dev/kvm ] || { echo "falta /dev/kvm: revisar nestedVirtualization=true en .wslconfig" >&2; exit 1; }

pacman-key --init >/dev/null 2>&1
pacman-key --populate archlinux >/dev/null 2>&1
pacman -Syu --noconfirm --needed qemu-desktop edk2-ovmf virglrenderer mesa mesa-utils openssh

mkdir -p "$VM"
cp "$REPO/build/packer/output-arch/command-os-dev.qcow2" "$REPO/build/packer/output-arch/efivars.fd" "$VM/"
# El efivars.fd se creó con el firmware de QEMU para Windows; usar el mismo code.fd
cp "/mnt/c/Program Files/qemu/share/edk2-x86_64-code.fd" "$VM/"
cp "$REPO/build/packer/keys/packer_build_key" "$VM/"
chmod 600 "$VM/packer_build_key"
qemu-img check "$VM/command-os-dev.qcow2"
