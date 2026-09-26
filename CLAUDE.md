# Command OS — contexto para retomar el proyecto

## Qué es esto

Distro propia para un cyberdeck comercial, construida como capa de curación
(Hyprland/Wayland, theming, apps por defecto, instalador) sobre Arch Linux
ARM en el hardware real (Raspberry Pi 5) — modelo Omarchy, pero sobre una
base aarch64 oficial en vez de x86_64. Un colega hace el hardware, este repo
es la parte de software/SO. Ver `README.md` para la estructura del repo.

**Estado actual**: el pipeline de instalación (`os/install.sh` + paquetes +
dotfiles) está probado y funciona de punta a punta en una VM x86_64 de
desarrollo (QEMU, en Windows). Falta: verificación visual de Hyprland
renderizado (ver más abajo, es la parte pendiente), y todavía no se probó
nada sobre Arch Linux ARM / hardware real.

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

## Decisión pendiente (esto es lo primero a retomar)

Se le propuso al usuario probar **WSL2 con KVM anidado** como último intento
razonable para lograr ver Hyprland renderizado en la PC Windows del usuario
(la idea: un kernel Linux real dentro de WSL2 haciendo la virtualización de
GPU con KVM nativo, en vez de que Windows/WHPX traduzca con ANGLE — es una
combinación con mejor track record para wlroots+virtio-gpu-gl). **Todavía no
se ejecutó** — quedó en "¿seguimos con eso?" sin respuesta del usuario al
momento de escribir esto. Si el usuario confirma, ese es el siguiente paso.
Si WSL2+KVM también falla o se cuelga, la recomendación acordada es dejar de
perseguir la verificación visual en VM y esperar al Raspberry Pi 5 físico
para eso (la GPU real del Pi no tiene ninguno de estos problemas).

## Cómo retomar la VM de desarrollo

Ver `docs/testing.md` para comandos exactos. Resumen:
- Disco ya instalado en `build/packer/output-arch/command-os-dev.qcow2`
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
