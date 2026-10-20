# Historial de las VM y de QEMU/Packer (qué se probó y qué se descartó)

Movido desde `AGENTS.md`. Sirve para no repetir pruebas que ya fallaron. Los pasos actuales están
en `docs/testing.md` y `docs/notas/vm-virtualbox-wsl.md`.

1. **VirtualBox con `vmsvga`/`vmwgfx` → descartado.** El compositor anterior no inicializaba sobre
   ese driver. Hoy la VM de VirtualBox usa `vboxsvga` con render por software y labwc va bien.

2. **QEMU + `virtio-gpu-pci` sin aceleración 3D**: sirve para validar que el instalador corre bien
   (paquetes/servicios/dotfiles); para ver el escritorio, mejor la VM de VirtualBox.

3. **QEMU + `virtio-gpu-gl-pci` con `-display sdl,gl=on` (aceleración 3D) → cuelga la VM.** En este
   host (Windows + WHPX), ambos vCPUs se van al 100 % sin avanzar el arranque. No se investigó más
   (¿ANGLE/EGL + WHPX incompatibles?). Fue lo último que se intentó antes de decidir el plan actual.

4. **El tecleo automático de Packer (`boot_command`) es frágil** tanto en VirtualBox (PS2) como en
   QEMU (VNC), incluso con `boot_wait` alto y `boot_key_interval` ajustado: a veces la llave SSH no
   queda bien escrita y Packer espera SSH indefinidamente. Lo que funcionó: abrir la ISO en una
   ventana visible de QEMU y que el humano corra 4 comandos cortos a mano (`passwd`,
   `systemctl start sshd`), y desde ahí inyectar la llave real por SSH con contraseña (con
   `SSH_ASKPASS`, no interactiva). Pasos exactos en `docs/testing.md`.

5. **Nunca matar el proceso de QEMU con `Stop-Process -Force` / `kill -9`.** Corrompe archivos
   recién escritos (pasó con `getty@tty1.service.d/override.conf`, lleno de bytes nulos). Siempre
   `shutdown -h now` por SSH antes de cerrar la ventana o el proceso.

## Las VM viejas de QEMU

Los discos QEMU (`/root/vm/command-os-dev.qcow2` en WSL, `build/packer/output-arch/` en Windows)
son anteriores a labwc y llevan el escritorio viejo: **reconstruirlos** (Packer o
`build/x86/build-image.sh`) en vez de re-correr `os/install.sh` encima, que ya no limpia el
escritorio anterior. La llave SSH efímera está en `build/packer/keys/packer_build_key` (ignorada
por git; regenerarla si no existe, ver `docs/testing.md`).
