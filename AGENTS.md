# Command OS — contexto para retomar el proyecto

## Qué es esto

Distro propia para un cyberdeck comercial, construida como capa de curación
(labwc/Wayland, theming, apps por defecto, instalador) sobre Arch Linux
ARM en el hardware real (Raspberry Pi 5) — modelo Omarchy, pero sobre una
base aarch64 oficial en vez de x86_64. Un colega hace el hardware, este repo
es la parte de software/SO. Ver `README.md` para la estructura del repo.

Ecosistema Command: sigue `ESTANDAR.md` de `command-web`
(https://github.com/command-designs/command-web/blob/main/ESTANDAR.md) en lo que aplique a un proyecto
que no es web (§ 12 para dispositivos).

**Estado actual**: escritorio **labwc**. Desde el 2026-10-06 Command OS es un **paquete de pacman**
(`os/pkg`) con configuración de serie en el sistema, ganchos de pacman, bloqueo a prueba de
roturas, Arch de una fecha validada (x86), btrfs con instantáneas y pruebas automáticas en GitHub
Actions. **Cómo funciona y por qué: `docs/actualizaciones.md` (leerlo antes de tocar la
instalación).** Desde el 2026-10-07 no hay cuenta de serie: greetd con asistente de primer arranque,
pantalla de inicio de sesión propia e inicio automático opcional (`docs/cuentas.md`). Verificado en la VM x86_64 de VirtualBox. Falta: hardware real (lo prueba el
usuario) y Arch Linux ARM.

## Qué leer según la tarea (detalle en `docs/notas/`, léelo antes de tocar esa zona)

| Si vas a tocar… | Lee |
| --- | --- |
| paquete, ganchos de pacman, bloqueo, repositorio firmado, instantáneas | `docs/actualizaciones.md` y `docs/notas/estabilidad.md` |
| cuentas, contraseñas, primer arranque, inicio de sesión, greetd | `docs/cuentas.md` |
| escritorio labwc, Waybar, fondos, sonidos, menús, escritorios virtuales | `docs/notas/escritorio.md` y `docs/DISENO.md` |
| splash, GRUB, arranque silencioso, imagen x86, USB, dual boot, bare metal | `docs/notas/arranque-e-imagenes.md` y `docs/dualboot.md` |
| VM de VirtualBox, WSL2, capturas, pruebas a mano | `docs/notas/vm-virtualbox-wsl.md` y `docs/testing.md` |
| por qué se decidió algo (y qué se descartó) | `docs/decisiones.md` |
| qué viene ahora | `ROADMAP.md` (se quita cada punto al terminarlo y verificarlo) |

## Trampas que ya han roto algo (resumen; el porqué está en `docs/notas/`)

- XML de labwc: **ningún comentario puede contener `--`**: labwc deja de leer el archivo entero.
- labwc suma las listas de escritorios al combinar configuraciones: la de serie no lleva `<names>`.
- Waybar: la configuración de serie va en `/usr/share/command-os/config/waybar/` y se pasa con
  `--config/--style` (`command-os-config`); `/etc/xdg/waybar/` ya existe por Arch.
- hyprlock con errores de configuración no sale: pantalla en negro y sin campo. `command-os-lock` revisa antes.
- VirtualBox: **apagar la VM antes de que el PC entre en reposo** (se congela; recuperación en `docs/notas/vm-virtualbox-wsl.md`).
- Nunca matar QEMU con `Stop-Process -Force` / `kill -9` (corrompe archivos): `shutdown -h now` por SSH antes.
- Scripts `.sh` siempre con LF. `runuser` conserva el entorno de root (`as_user` fija HOME). En un chroot
  `systemd-detect-virt` ve el anfitrión (WSL): `is_vm` lo descarta.
- WSL cierra los procesos `setsid nohup` al terminar `wsl.exe`: para construir imágenes, `wsl.exe` en primer plano.
- Plymouth no se puede probar en WSL: probar en la VM. Al iterar con labwc, `kill -HUP $(pidof labwc)`;
  reiniciar hypridle por SSH lo deja escuchando la sesión SSH, no la de tty1.
- Cada cambio vale a la vez para x86 (GRUB, `/etc/default/grub`) y ARM/Pi 5 (`cmdline.txt`).
- tty1 es de greetd: para una sesión nueva, `systemctl restart greetd` (no `getty@tty1`). Si la entrada
  falla, tty2 es la consola de emergencia. `deck`/`deck` es solo de desarrollo (`COMMAND_OS_DEV_USER`).
- VirtualBox: **nunca `snapshot take --live`** con la VM encendida: la deja congelada (pasó con
  `command-os-x86`). Instantáneas con la VM apagada.

## Qué se probó y qué se descartó (no repetir)

1. **VirtualBox con `vmsvga`/`vmwgfx` → descartado.** El compositor anterior no inicializaba sobre
   ese driver. Hoy la VM de VirtualBox usa `vboxsvga` con render por software y labwc va bien (ver
   "Identidad de marca y VM en VirtualBox").

2. **QEMU + `virtio-gpu-pci` sin aceleración 3D**: sirve para validar que el instalador corre bien
   (paquetes/servicios/dotfiles); para ver el escritorio, mejor la VM de VirtualBox.

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

## Siguientes pasos

En `ROADMAP.md`, por orden. Cada punto se quita al terminarlo y verificarlo.

## Cómo retomar la VM de desarrollo

Ver `docs/testing.md` para comandos exactos. Resumen:
- Forma preferida para el escritorio: VM de VirtualBox `command-os-x86` (SSH `127.0.0.1:2902` como
  `deck`), ya con labwc.
- Los discos QEMU (`/root/vm/command-os-dev.qcow2` en WSL, `build/packer/output-arch/` en Windows)
  son anteriores a labwc y llevan el escritorio viejo: **reconstruirlos** (Packer o
  `build/x86/build-image.sh`) en vez de re-correr `os/install.sh` encima, que ya no limpia el
  escritorio anterior.
- Llave SSH efímera en `build/packer/keys/packer_build_key` (gitignored,
  regenerar si no existe — ver `docs/testing.md`).
- Credenciales de desarrollo (no usar en producto final): usuario `deck` /
  password `deck` (solo imágenes con `DEV_SSH_PUBKEY`/`COMMAND_OS_DEV_USER`); `root` bloqueado.

## Convenciones del repo

- `os/` es el producto real (paquetes, install.sh, dotfiles) — arquitectura
  agnóstico, se usa igual en la VM x86_64 y (a futuro) en ARM/Pi.
- `build/packer/` es solo tooling de desarrollo para levantar la VM de
  pruebas rápido, no es parte del producto.
- Scripts `.sh` deben mantenerse con line endings LF (forzado por
  `.gitattributes`) — si un editor los toca y los pasa a CRLF, van a romper
  al ejecutarse dentro de la VM Linux.

## Compact instructions

Al compactar, conserva: la rama activa, las decisiones tomadas, el estado de las VM (`command-os-x86`,
`command-os-btrfs`) y los resultados de las pruebas.
