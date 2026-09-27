#!/bin/sh
# Arranca la VM de desarrollo dentro de WSL2 con KVM y virtio-vga-gl.
# Cadena gráfica: virgl (guest) -> virglrenderer -> Mesa d3d12 -> GPU del host.
#   wsl -d archlinux -u root -- sh /mnt/c/<ruta al repo>/build/wsl/run-vm.sh [vnc|wslg]
#
# Modos de display:
#   vnc  (default) La ventana SDL de QEMU va a un X virtual (Xvnc) dentro de WSL;
#        se ve desde Windows con TigerVNC en localhost:5901. Evita WSLg, cuyo
#        transporte RDP produce tearing y lag con un compositor animado.
#   wslg La ventana SDL va directo al escritorio de Windows vía WSLg.
# Resolución del guest: RES=1920x1080 (default 1280x800).
# SSH al guest en 127.0.0.1:2900 (desde WSL).
MODE=${1:-vnc}
RES=${RES:-1280x800}
W=${RES%x*}
H=${RES#*x}
cd /root/vm
# Sin esto Mesa en WSL cae a llvmpipe (software) en vez de usar la GPU real
export GALLIUM_DRIVER=d3d12

if [ "$MODE" = vnc ]; then
  pkill -x Xvnc 2>/dev/null
  # Sin password: solo escucha en localhost (WSL lo reenvía al localhost de Windows)
  Xvnc :1 -geometry "$RES" -depth 24 -SecurityTypes None -localhost -AlwaysShared \
    >/root/vm/xvnc.log 2>&1 &
  sleep 1
  export DISPLAY=:1
  unset WAYLAND_DISPLAY
  export SDL_VIDEODRIVER=x11
  FULL=-full-screen
fi

exec qemu-system-x86_64 -M q35 -accel kvm -cpu host -m 4096 -smp 4 \
  -drive if=pflash,format=raw,readonly=on,file=edk2-x86_64-code.fd \
  -drive if=pflash,format=raw,file=efivars.fd \
  -drive file=command-os-dev.qcow2,if=virtio,format=qcow2 \
  -device virtio-vga-gl,xres="$W",yres="$H" -display sdl,gl=on $FULL \
  -device qemu-xhci -device usb-tablet \
  -netdev user,id=net0,hostfwd=tcp::2900-:22 -device virtio-net-pci,netdev=net0
