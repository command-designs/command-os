# Notas: arranque silencioso, imágenes x86, USB y dual boot

Detalle movido de `CLAUDE.md` sin cambios (2026-10-06). Guía de dual boot: `docs/dualboot.md`.

## Siguiente paso: bare metal (esto es lo primero a retomar)

**Arrancar Command OS en bare metal desde un USB en la PC de desarrollo**,
para probar la UX del escritorio (atajos con Super, waybar, apps, theming) con
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
sistema queda `running` y el escritorio renderiza (captura con `grim`). **No
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
  con `--skip-login --nonewline --noissue --nohints`, `~/.hushlogin`, y `labwc` con la salida a
  `$XDG_RUNTIME_DIR/labwc.log` (no a tty1). labwc reutiliza el modo del splash
  (`<reuseOutputMode>`); en VirtualBox hay ~2 s de negro por el cambio a 1280x720.
- **Verificado en la VM x86** con capturas cada segundo de arranque y reinicio.
- Plymouth no se puede probar en WSL (el daemon se cuelga sin tty): probar en la VM
  (`VBoxManage controlvm command-os-x86 screenshotpng` durante el arranque).
