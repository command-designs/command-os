# Notas: VM de VirtualBox, WSL2 y marca en la VM

Detalle movido de `CLAUDE.md` sin cambios (2026-10-06). Comandos exactos: `docs/testing.md`.

## Identidad de marca y VM en VirtualBox (2026-10-01)

- **Marca:** desde el 2026-10-04 el escritorio es un **HUD estilo Cyberpunk 2077 con ADN Command**
  (decisión del usuario, sustituye a la paleta casi monocromo). Desde el mismo día, en los tonos
  apagados de los menús de 2077 (el neón le parecía chillón): rojo `#D13449` primario (el que eligió
  el usuario), cian `#5BBFC4` secundario, ámbar `#E2C044` solo avisos, esquinas vivas, halo suave
  en vez de blur. Las apps GTK/Qt (Thunar, Firefox, pavucontrol) siguen el mismo tema: `adw-gtk3-dark`
  recoloreado en `os/dotfiles/gtk-{3,4}.0/gtk.css`, Papirus-Dark y modo oscuro por dconf. Se mantiene de `BRAND.md` (`C:\Workspace\command\command-web`): wordmark con barra Signal
  Red, Oxanium/Geist/JetBrains Mono, voz en minúsculas, curva de movimiento. Paleta, reglas y
  estado de cada ancla en `docs/DISENO.md`. Assets en `os/branding/`
  (logo, fuentes OFL, wallpaper, tema Plymouth); se regeneran con `build/make-wallpaper.py` y
  `build/make-plymouth.py`. El instalador también cambia `os-release`, `issue`, `motd` y GRUB.
- **VirtualBox sí sirve ahora** para probar el escritorio (contradice el punto 1 de "Qué se
  descartó", que era sobre la config vieja): VM `command-os-x86`, disco
  `build/x86/vbox/command-os-x86.vdi`, SSH `127.0.0.1:2902` como `deck` (con
  `build/packer/keys/packer_build_key`; `root` está bloqueado en esta imagen, sudo con `deck`).
  **vCPU**: sin hotplug, con 2 el firmware EFI se cuelga en `DXE_AP`; con `--cpu-hotplug on` arranca
  con 4 (2026-10-04). VirtualBox corre sobre Hyper-V (NEM) porque WSL2 lo mantiene activo. También
  chipset ICH9 y HPET on. Render por software, 1280x720 fijo (~13 FPS); `vmsvga`+3D descartado.
  Detalle en `docs/testing.md`. El arranque tarda >1 min. labwc renderiza (render por software).
- El módulo `image` de Waybar 0.15 se bloquea (futex) incluso con un PNG pequeño: el logo va como
  `custom/logo` con `background-image` en CSS.
- La imagen usa initramfs con hook `systemd`: `plymouth` va después de `systemd`, no de `udev`.
- Pendiente del tema: ver la animación de arranque en movimiento (solo vi el fotograma final),
  hacer el splash saltable, hyprlock y el fondo (swaybg) en pantallas reales, y el paquete pacman
  `command-os` (segunda pasada).


## Verificación visual en VM: WSL2 + KVM anidado (2026-09-27)

El escritorio **sí renderiza** en la VM de desarrollo corriendo QEMU dentro de
WSL2 (Arch oficial para WSL, `wsl -d archlinux -u root`) con `-accel kvm
-cpu host -device virtio-vga-gl -display sdl,gl=on`. Cadena gráfica: virgl
en el guest → virglrenderer → Mesa d3d12 → GTX 1650 Super; la ventana se ve
en Windows vía WSLg. Confirmado con captura `grim` dentro del guest
(wallpaper + waybar, 1280x800) y el renderer del log
(`virgl (D3D12 (NVIDIA GeForce GTX 1650 SUPER))`).

Detalles que importan:
- **`GALLIUM_DRIVER=d3d12` es obligatorio** en el anfitrión WSL: sin eso
  Mesa cae a `llvmpipe` (software).
- virgl da GLES 3.1: los avisos de contexto GLES 3.2 en el log son benignos.
- Host: i5-10400F, 16 GB, GTX 1650 Super; `%USERPROFILE%\.wslconfig` con
  `nestedVirtualization=true`, `memory=10GB`, `processors=10`.
- El anfitrión WSL NO es el producto, solo corre QEMU; el producto es el
  qcow2. La copia de trabajo del disco vive en `/root/vm` dentro de WSL
  (correr desde `/mnt/c` es lento); la de `build/packer/output-arch/` en
  Windows queda como respaldo y **ya no está sincronizada** con la de WSL.
- **Pero no es usable para probar a mano.** Vía WSLg (RDP) se ve cortado y
  con lag. Vía `Xvnc` en WSL + TigerVNC en Windows (`run-vm.sh` modo `vnc`)
  sigue con mucho lag, se ve chico (1280x800 en monitor 1440p) y los clicks
  no llegaban (no se diagnosticó). `egl-headless`/SPICE-GL de QEMU no
  sirven: WSL no tiene `/dev/dri`. Además Windows se come la tecla Super,
  que es la base de los atajos. Conclusión: la VM sirve para validar el
  instalador y ver que el escritorio arranca, no para probar la UX (para eso,
  la VM de VirtualBox).
- Scripts: `build/wsl/setup.sh` y `build/wsl/run-vm.sh`. Pasos en
  `docs/testing.md`.
