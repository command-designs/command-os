#!/bin/sh
# Arranca la imagen x86 (build-image.sh) en QEMU+KVM dentro de WSL, con un
# NVRAM UEFI nuevo y vacío: así se prueba que el arranque por la ruta
# removable (EFI/BOOT/BOOTX64.EFI) funciona igual que en un USB real.
#   wsl -d archlinux -u root -- sh /mnt/c/<repo>/build/x86/run-vm.sh
# Display: Xvnc en 127.0.0.1:5901 (TigerVNC). SSH al guest: 127.0.0.1:2901.
IMG=${IMG:-/root/vm/command-os-x86.img}
RES=${RES:-1280x800}
W=${RES%x*}; H=${RES#*x}
cd /root/vm
[ -f edk2-x86_64-code.fd ] || cp "/mnt/c/Program Files/qemu/share/edk2-x86_64-code.fd" .
cp "/mnt/c/Program Files/qemu/share/edk2-i386-vars.fd" efivars-x86.fd
export GALLIUM_DRIVER=d3d12
pkill -x Xvnc 2>/dev/null
Xvnc :1 -geometry "$RES" -depth 24 -SecurityTypes None -localhost -AlwaysShared >/root/vm/xvnc.log 2>&1 &
sleep 1
export DISPLAY=:1 SDL_VIDEODRIVER=x11
unset WAYLAND_DISPLAY
exec qemu-system-x86_64 -M q35 -accel kvm -cpu host -m 4096 -smp 4 \
  -drive if=pflash,format=raw,readonly=on,file=edk2-x86_64-code.fd \
  -drive if=pflash,format=raw,file=efivars-x86.fd \
  -drive file="$IMG",if=virtio,format=raw \
  -device virtio-vga-gl,xres="$W",yres="$H" -display sdl,gl=on -full-screen \
  -device qemu-xhci -device usb-tablet \
  -netdev user,id=net0,hostfwd=tcp::2901-:22 -device virtio-net-pci,netdev=net0
