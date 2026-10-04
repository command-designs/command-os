# Command OS — contexto para retomar el proyecto

## Qué es esto

Distro propia para un cyberdeck comercial, construida como capa de curación
(Hyprland/Wayland, theming, apps por defecto, instalador) sobre Arch Linux
ARM en el hardware real (Raspberry Pi 5) — modelo Omarchy, pero sobre una
base aarch64 oficial en vez de x86_64. Un colega hace el hardware, este repo
es la parte de software/SO. Ver `README.md` para la estructura del repo.

**Estado actual**: el pipeline de instalación (`os/install.sh` + paquetes +
dotfiles) está probado — ojo: es una base Hyprland mínima, todavía no se
parece a Omarchy (la meta real, ver "Objetivo" en `README.md`: CachyOS +
Omarchy en ARM, que no existen para aarch64, así que se replica sobre Arch
Linux ARM). El pipeline funciona de punta a punta en una VM x86_64 de
desarrollo (QEMU), y Hyprland se ve renderizado corriendo esa VM dentro de
WSL2 con KVM + virgl (ver "Verificación visual" más abajo). Falta: todavía
no se probó nada sobre Arch Linux ARM / hardware real.

## Qué se probó y qué se descartó (no repetir)

1. **VirtualBox como VM de desarrollo → descartado.** El driver `vmwgfx`
   que usa VirtualBox para GPU virtual se autodetecta como "corriendo en
   hipervisor no soportado" y Hyprland/aquamarine crashea en un loop de
   asignación de CRTCs (confirmado con issues de GitHub de
   `hyprwm/aquamarine` y `hyprwm/Hyprland`, no es config nuestra). Se migró
   todo el pipeline de Packer a QEMU.

2. **QEMU + `virtio-gpu-pci` sin aceleración 3D → arranca bien, Hyprland
   crashea.** Sin 3D, `virtio-gpu` no da soporte GBM, mismo tipo de fallo
   que vmwgfx (`CBackend::create() failed`). Sirve para validar que el
   instalador corre bien (paquetes/servicios/dotfiles), no para ver
   Hyprland.

3. **QEMU + `virtio-gpu-gl-pci` con `-display sdl,gl=on` (aceleración 3D)
   → cuelga la VM.** En este host (Windows + WHPX), ambos vCPUs se van al
   100% sin avanzar el arranque. No se investigó más a fondo por qué
   (¿ANGLE/EGL + WHPX incompatibles?). Es la última cosa que se intentó
   antes de decidir el plan de abajo.

4. **El tecleo automático de Packer (`boot_command`) es frágil** tanto en
   VirtualBox (PS2) como QEMU (VNC), incluso con `boot_wait` alto y
   `boot_key_interval` ajustado — a veces la llave SSH no queda bien
   escrita y Packer se queda esperando SSH indefinidamente. La salida que
   funcionó: abrir la ISO en una ventana visible de QEMU y que el humano
   corra 4 comandos cortos a mano (`passwd`, `systemctl start sshd`), y
   desde ahí inyectar la llave real por una conexión SSH con password
   (usando `SSH_ASKPASS`, no interactiva). Pasos exactos en
   `docs/testing.md`.

5. **Nunca matar el proceso de QEMU con `Stop-Process -Force` / kill -9.**
   Corrompe archivos recién escritos en el disco (nos pasó con
   `getty@tty1.service.d/override.conf`, quedó lleno de bytes nulos).
   Siempre `shutdown -h now` por SSH antes de cerrar la ventana/proceso.

## Siguientes pasos de producto

Lista priorizada en `README.md` → "Siguientes pasos" (probar notificaciones/bloqueo/atajos, splash
saltable, pantalla de info `CMD-OS`, paquete pacman `command-os`, instalador pulido, bare metal, Pi 5).

## Siguiente paso: bare metal (esto es lo primero a retomar)

**Arrancar Command OS en bare metal desde un USB en la PC de desarrollo**,
para probar la UX de Hyprland (atajos con Super, waybar, apps, theming) con
fluidez nativa, sin VM. Propuesto al usuario el 2026-09-27; todavía no
confirmó si tiene un USB ≥32 GB a mano — preguntarle eso primero. No
reemplaza la prueba en el Raspberry Pi 5 (el hardware real), es el puente
hasta tenerlo.

Plan:
1. Variante x86 de desarrollo con driver NVIDIA para la GTX 1650 Super
   (Turing → `nvidia-open` + `nvidia-utils`, KMS habilitado con
   `nvidia_drm.modeset=1`). Solo para esta build de pruebas, **no** va en
   `os/packages.txt` del producto (el Pi usa la GPU de Broadcom/V3D).
2. Grabar la imagen al USB desde WSL: `wsl --mount \\.\PHYSICALDRIVE<n>
   --bare` (PowerShell elevado; identificar el disco con `Get-Disk` y
   confirmar con el usuario antes de escribir — **no equivocarse de disco**)
   y `qemu-img convert` / `dd` del qcow2 al dispositivo. Alternativa: bootear
   la ISO de Arch desde el USB y correr `build/packer/scripts/01-base-install.sh` +
   `os/install.sh` apuntando a un segundo USB.
3. Revisar que el arranque no dependa de algo de la VM. Ya se sabe que
   **falla tal cual**: `01-base-install.sh` hace `grub-install` sin
   `--removable`, así que GRUB queda registrado solo en la NVRAM de la VM
   (`efivars.fd`) y el USB no tiene `EFI/BOOT/BOOTX64.EFI` — agregar
   `--removable`. Revisar también fstab por UUID y microcode.
4. El usuario reinicia y elige el USB en el menú de arranque de la BIOS; su
   Windows no se toca.

## Imagen x86 para USB / bare metal (2026-10-01)

Ya existe la variante x86 pensada para el PC de desarrollo:
`build/x86/build-image.sh` (en WSL, como root) genera
`/root/vm/command-os-x86.img` (raw, GPT, ESP 1 GB + ext4, 14 GB sparse) con
Arch + `os/install.sh` con `COMMAND_OS_VARIANT=pc-nvidia`
(`os/variants/pc-nvidia/packages.txt`: `nvidia-open`, `nvidia-utils`,
ucode Intel/AMD) y GRUB con `--removable --no-nvram`
(`EFI/BOOT/BOOTX64.EFI`, cmdline `nvidia_drm.modeset=1 nvidia_drm.fbdev=1`).
`build/x86/run-vm.sh` la arranca en QEMU+KVM con un NVRAM UEFI vacío (SSH en
`127.0.0.1:2901`). **Verificado en VM**: arranca por la ruta removable, el
sistema queda `running` y Hyprland renderiza (captura con `grim`). **No
verificado**: el driver NVIDIA real (en la VM no hay GPU NVIDIA) ni el
arranque desde un USB físico — falta el USB.
`/etc/profile.d/command-os-nvidia.sh` solo exporta variables NVIDIA si hay
GPU NVIDIA real. Ojo: `arch-chroot` monta un `/tmp` limpio, no copiar nada
a `/tmp` antes de entrar al chroot. Pendiente: grabar la imagen en el USB
(`dd`, confirmando el disco con el usuario).

## Dual boot con Windows (2026-10-04)

`build/x86/install-dualboot.sh /dev/<disco>` (desde el USB en vivo de Arch, como root) instala
Command OS en el mayor hueco libre del disco junto a Windows: partición ext4 nueva (`sgdisk -n
0:0:0`), reutiliza la ESP de Windows sin formatear (montada en `/efi`; kernel en `/boot` de la
ext4), GRUB en `EFI/command-os/` sin `--removable` (no pisa `EFI/Boot`), entrada fija de Windows en
`/etc/grub.d/35_command-os-windows` (chainload de `bootmgfw.efi` por UUID de la ESP; os-prober
no detectaba Windows sin udev), reloj en hora
local (`/etc/adjtime`), teclado `es` y variante `pc-nvidia` solo si hay GPU NVIDIA. Deja
`/etc/command-os/dualboot` → `install.sh` pone el menú de GRUB visible 5 s (sin la marca, menú
oculto 1 s como antes); `/etc/command-os/kb_layout` → `kb_layout` en `local.lua`.
Pensado para el portátil del colega; guía paso a paso en `docs/dualboot.md`. **Probado solo en WSL
sobre un disco loop** con un Windows falso (`NO_NVRAM=1`); falta un portátil real (entrada UEFI,
BitLocker). No aplica al Pi (sin GRUB); las ramas nuevas de `install.sh` solo se activan con la marca.

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
  Detalle en `docs/testing.md`. El arranque tarda >1 min. Hyprland renderiza (render por software).
- **Hyprland 0.56.2**: no existen `dwindle:pseudotile` ni el dispatcher `togglesplit` (usar
  `layoutmsg, togglesplit`); pide arrancar con `start-hyprland`. Si un módulo de Waybar rompe la
  barra, la capa queda con `a: 0` en `hyprctl layers`. El módulo `image` de Waybar 0.15 se bloquea
  (futex) incluso con un PNG pequeño: el logo va como `custom/logo` con `background-image` en CSS.
- La imagen usa initramfs con hook `systemd`: `plymouth` va después de `systemd`, no de `udev`.
- Re-ejecutar `os/install.sh` sobre la VM en marcha funciona (sin reconstruir la imagen), pero
  borra `~/.config/hypr` mientras Hyprland corre: sale un banner "autogenerated config" hasta
  `hyprctl reload`.
- Pendiente del tema: ver la animación de arranque en movimiento (solo vi el fotograma final),
  hacer el splash saltable, hyprlock/hyprpaper en pantallas reales, y el paquete pacman
  `command-os` (segunda pasada).

## Arranque silencioso para clientes (2026-10-04)

Del encendido al escritorio solo se ve el splash, con una consola de 6 líneas de servicios bajo la
barra (a petición del usuario, el mismo 2026-10-04: los logs solo dentro de la animación). Todo en `os/install.sh`, sección "Silent boot", para las dos plataformas:
- **Kernel**: `quiet splash loglevel=3 rd.udev.log_level=3 systemd.show_status=auto
  rd.systemd.show_status=auto vt.global_cursor_default=0`. x86 → `GRUB_CMDLINE_LINUX_DEFAULT`
  (`build/x86/build-image.sh` ya no la pisa, solo añade lo de NVIDIA). Pi → `/boot/cmdline.txt` con
  `console=tty1` → `console=tty3`, y `disable_splash=1` en `/boot/config.txt`. **La rama del Pi no
  está probada en hardware** (solo simulada con un `cmdline.txt` de Arch Linux ARM).
- **GRUB (x86)**: menú oculto 1 s (`GRUB_TIMEOUT_STYLE=hidden`; Esc lo muestra) y sin
  "Loading Linux…/initial ramdisk" (se borran los `echo "$message"` de `/etc/grub.d/10_linux`; una
  actualización de `grub` los restaura hasta volver a correr `install.sh`). `install.sh` ahora
  ejecuta `grub-mkconfig` si existe `/boot/grub/grub.cfg`.
- **Splash** (`command.script`): wordmark animado + barra fina + consola de servicios (systemd los
  manda a Plymouth aunque el arranque sea silencioso; verificado en VM); al apagar, sin barra. **Esc** pasa al
  modo detalles de Plymouth (soporte técnico; `details.so` va en el initramfs).
- **Paso al escritorio**: `plymouth quit --retain-splash` (drop-in de `plymouth-quit.service`), agetty
  con `--skip-login --nonewline --noissue --nohints`, `~/.hushlogin`, y `start-hyprland` con la salida
  a `/dev/null` (si no, su logo ASCII y su log salen en tty1). Hay ~3 s de negro entre el splash y
  Hyprland (modeset).
- **Verificado en la VM x86** con capturas cada segundo de arranque y reinicio.
- **Configuración Lua (resuelto el 2026-10-04)**: `os/dotfiles/hypr/hyprland.lua` sustituye a
  `hyprland.conf`, así que ya no sale el aviso "support for .conf will be removed in 0.57". API en
  `/usr/share/hypr/stubs/hl.meta.lua` y wiki (`github.com/hyprwm/hyprland-wiki`, `content/configuring`).
  Consecuencias: `hyprctl dispatch` solo acepta dispatchers Lua (hypridle ya usa
  `hl.dsp.dpms(...)`), y **Waybar 0.15 manda `dispatch workspace N` antiguo**, así que la barra usa
  `ext/workspaces` (protocolo ext-workspace) con los espacios 1-4 persistentes por regla de Hyprland.
  Waybar master ya traduce a Lua; cuando salga en Arch se puede volver a `hyprland/workspaces`.
- Plymouth no se puede probar en WSL (el daemon se cuelga sin tty): probar en la VM
  (`VBoxManage controlvm command-os-x86 screenshotpng` durante el arranque).

## Menú de energía y mezclador (2026-10-04)

- `os/bin/command-os-power`: Super+Escape o botón 󰐥 de la barra → bloquear / reiniciar / apagar (con
  confirmación), por logind sin contraseña. Verificado en VM: apagado limpio en ~6 s.
- `os/bin/command-os-volume`: clic en `vol` → pavucontrol flotante 460×340 bajo la barra (regla en
  `hyprland.lua`); otro clic lo cierra.
- VirtualBox: la X de la ventana pregunta; "Enviar la señal de apagado" es limpio, "Apagar la
  máquina" es desenchufar.

## Consola de desarrollo, animaciones y sonido (2026-10-01)

- **Paquetes de desarrollo** en `os/packages.txt` (nano, base-devel, man, ripgrep, fd, fzf, bat, eza,
  zoxide, tmux, jq, python, nodejs/npm…) y pila de audio PipeWire completa. `install.sh` instala
  `~/.config/command-os/bashrc` (alias, prompt de marca, `EDITOR=nano`) enganchado desde `~/.bashrc`
  con marcadores, y `~/.config/nano/nanorc`.
- **Animaciones**: animaciones de `hyprland.lua` (antes `hyprland.conf`) rehechas (entradas/salidas de ventanas, capas,
  espacios de trabajo, fundidos) + transiciones CSS en Waybar. `install.sh` escribe
  `~/.config/hypr/local.lua` (cargado con `require("local")` al final) con un perfil ligero **solo en VM**.
- **Sonidos**: `build/make-sounds.py` los genera en `os/branding/sounds/`; `os/bin/command-os-sound`
  los reproduce (arranque, notificación, urgente, bloqueo, desbloqueo, tecla de volumen).
- **VirtualBox**: 4 vCPU solo con CPU hotplug (sin hotplug, 2 vCPU = cuelgue en `DXE_AP`), 6 GB de
  RAM, paravirt KVM, y **audio AC97** (con HDA `pw-play` se cuelga). Hyprland renderiza por software
  en la VM, así que la fluidez real de las animaciones solo se juzga en bare metal / Pi. Detalle en
  `docs/testing.md`.
- Ojo al iterar: re-ejecutar `install.sh` con Hyprland en marcha lo **cuelga** (recarga automática con
  `~/.config/hypr` a medias, bloqueado en un futex). Después de re-instalar, reiniciar la sesión con
  `sudo systemctl restart getty@tty1` en lugar de `hyprctl reload`.
- Pendiente: oír los sonidos en la VM (solo se verificó que `pw-play` termina a tiempo, no el
  resultado acústico), validar los paquetes en aarch64 y probar el audio en el Pi.

## Verificación visual en VM: WSL2 + KVM anidado (2026-09-27)

Hyprland **sí renderiza** en la VM de desarrollo corriendo QEMU dentro de
WSL2 (Arch oficial para WSL, `wsl -d archlinux -u root`) con `-accel kvm
-cpu host -device virtio-vga-gl -display sdl,gl=on`. Cadena gráfica: virgl
en el guest → virglrenderer → Mesa d3d12 → GTX 1650 Super; la ventana se ve
en Windows vía WSLg. Confirmado con captura `grim` dentro del guest
(wallpaper + waybar, 1280x800) y el log de aquamarine
(`Renderer: virgl (D3D12 (NVIDIA GeForce GTX 1650 SUPER))`).

Detalles que importan:
- **`GALLIUM_DRIVER=d3d12` es obligatorio** en el anfitrión WSL: sin eso
  Mesa cae a `llvmpipe` (software).
- El `ERR ... eglCreateContext failed with GLES 3.2, retrying GLES 3.0` en
  el log de Hyprland es benigno (virgl da GLES 3.1).
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
  que es la base de los atajos de Hyprland. Conclusión: la VM sirve para
  validar el instalador y ver que Hyprland arranca, no para probar la UX.
- Scripts: `build/wsl/setup.sh` y `build/wsl/run-vm.sh`. Pasos en
  `docs/testing.md`.

## Cómo retomar la VM de desarrollo

Ver `docs/testing.md` para comandos exactos. Resumen:
- Forma preferida: dentro de WSL (`build/wsl/run-vm.sh`), disco en
  `/root/vm/command-os-dev.qcow2`. SSH desde WSL a `127.0.0.1:2900` con
  `/root/vm/packer_build_key`.
- Disco original (Windows) en `build/packer/output-arch/command-os-dev.qcow2`
  (Arch base + capa Hyprland completa, usuario `deck`, servicios
  habilitados) — no hace falta reinstalar desde cero para seguir iterando
  dotfiles/paquetes, solo re-correr `os/install.sh` sobre él.
- Llave SSH efímera en `build/packer/keys/packer_build_key` (gitignored,
  regenerar si no existe — ver `docs/testing.md`).
- Credenciales de desarrollo (no usar en producto final): usuario `deck` /
  password `deck`; `root` sin password, solo por la llave SSH.

## Convenciones del repo

- `os/` es el producto real (paquetes, install.sh, dotfiles) — arquitectura
  agnóstico, se usa igual en la VM x86_64 y (a futuro) en ARM/Pi.
- `build/packer/` es solo tooling de desarrollo para levantar la VM de
  pruebas rápido, no es parte del producto.
- Scripts `.sh` deben mantenerse con line endings LF (forzado por
  `.gitattributes`) — si un editor los toca y los pasa a CRLF, van a romper
  al ejecutarse dentro de la VM Linux.
