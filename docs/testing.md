# Ciclo de pruebas en la VM de desarrollo (x86_64, QEMU)

## Por qué QEMU y no VirtualBox

Se probó primero con VirtualBox, pero Hyprland (vía su backend `aquamarine`)
no logra inicializar sobre el driver gráfico virtual de VirtualBox
(`vmwgfx`): el propio kernel lo marca como "corriendo en un hipervisor no
soportado", y aquamarine entra en un loop intentando asignar CRTCs a los
conectores fantasma que expone. Es un problema de compatibilidad conocido
(ver issues de `hyprwm/aquamarine` y `hyprwm/Hyprland` en GitHub), no algo
que se arregle con configuración. QEMU con `virtio-gpu` es la combinación
estándar y documentada para correr compositores wlroots en una VM, y además
es la misma herramienta que ya estaba planeada para validar la arquitectura
ARM más adelante.

## Qué SÍ y qué NO se valida en esta VM

- **QEMU nativo de Windows (WHPX)**: sirve para validar que `os/install.sh`
  corre sin errores — paquetes, usuario, dotfiles, servicios, autologin — pero
  **no** para ver Hyprland: sin aceleración 3D no hay GBM y Hyprland no
  arranca; con `virtio-gpu-gl-pci` + `-display sdl,gl=on` la VM cuelga
  (~100% CPU sin avanzar).
- **QEMU dentro de WSL2 con KVM anidado**: Hyprland **sí** renderiza (virgl →
  Mesa d3d12 → GPU del host, ventana vía WSLg). Es la forma preferida. Ver
  la sección siguiente.

## VM con Hyprland renderizado: QEMU dentro de WSL2 + KVM

Requisitos (una sola vez, ya hecho en la PC de desarrollo): WSL2 instalado,
`%USERPROFILE%\.wslconfig` con `nestedVirtualization=true` (más
`memory=10GB`, `processors=10`), y la distro oficial de Arch:
```
wsl --install -d archlinux --no-launch
```

Preparar el anfitrión (instala QEMU/OVMF/virglrenderer/Mesa y copia disco,
`efivars.fd`, firmware y llave SSH a `/root/vm` dentro de WSL — correr desde
`/mnt/c` es lento). **Ojo**: re-correrlo sobreescribe la copia de WSL con la
de Windows.
```
wsl -d archlinux -u root -- sh /mnt/c/Workspace/command/command-os/build/wsl/setup.sh
```

Arrancar la VM y verla con TigerVNC (`winget install TigerVNC.TigerVNC`):
```
wsl -d archlinux -u root -- sh /mnt/c/Workspace/command/command-os/build/wsl/run-vm.sh
"C:\Program Files\TigerVNC\vncviewer.exe" -AutoSelect=0 -PreferredEncoding=Raw -FullColor 127.0.0.1::5901
```
Por defecto la ventana de QEMU va a un X virtual (`Xvnc :1`) dentro de WSL y
no a WSLg: WSLg transporta las ventanas por RDP (`msrdc.exe`) y con un
compositor animado se ve cortado (tearing) y con lag. `run-vm.sh wslg` usa
el camino viejo (ventana directa vía WSLg). `RES=1920x1080` cambia la
resolución del guest. WSL no expone `/dev/dri`, así que `-display
egl-headless` / `spice gl=on` de QEMU no funcionan acá.

`run-vm.sh` exporta `GALLIUM_DRIVER=d3d12`: sin eso Mesa en WSL usa
`llvmpipe` (software) y no la GPU real. En el log de Hyprland aparece
`eglCreateContext failed with GLES 3.2, retrying GLES 3.0` — es benigno.

Desde WSL, SSH y captura de pantalla del compositor:
```
ssh -i /root/vm/packer_build_key -p 2900 root@127.0.0.1
# dentro del guest (grim no viene en la imagen, instalarlo si hace falta):
su deck -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-1 \
  HYPRLAND_INSTANCE_SIGNATURE=$(ls -t /run/user/1000/hypr | head -1) grim /tmp/shot.png'
```

Para iterar sobre `os/` desde WSL, el repo está en
`/mnt/c/Workspace/command/command-os`: mismo `scp` + `install.sh` que en la
sección "Ciclo de iteración" pero con `-i /root/vm/packer_build_key`.

Apagar siempre con `ssh ... 'shutdown -h now'` (nunca matar QEMU).

## Build inicial

```
cd build/packer
ssh-keygen -t ed25519 -N "" -f ./keys/packer_build_key -C packer-build
packer init .
packer build \
  -var iso_path=../iso/archlinux-x86_64.iso \
  -var "ssh_public_key=$(cat ./keys/packer_build_key.pub)" \
  .
```

`keys/` está en `.gitignore` — el par de llaves es efímero, solo para que
Packer entre a la VM durante el build.

**Nota sobre el tecleo del boot_command**: Packer tipea los comandos de
arranque a ciegas (por VNC). En este entorno resultó frágil incluso con
`boot_key_interval` alto — si el build automático se queda trabado en
"Waiting for SSH to become available" por varios minutos, la salida más
rápida es bootstrapear la llave SSH a mano una vez:

1. Lanzar la ISO en una ventana visible de QEMU (sin Packer):
   ```
   qemu-system-x86_64.exe -M q35 -accel whpx -cpu qemu64 -m 4096 -smp 2 ^
     -drive if=pflash,format=raw,readonly=on,file="C:/Program Files/qemu/share/edk2-x86_64-code.fd" ^
     -drive if=pflash,format=raw,file=output-arch/efivars.fd ^
     -drive file=output-arch/command-os-dev.qcow2,if=virtio,format=qcow2 ^
     -cdrom ../iso/archlinux-x86_64.iso -boot order=d ^
     -vga std -netdev user,id=net0,hostfwd=tcp::2900-:22 -device virtio-net-pci,netdev=net0
   ```
2. En la consola (`root@archiso`), correr `passwd` (poner algo simple) y
   `systemctl start sshd`.
3. Desde el host, conectar con password una vez para inyectar la llave real:
   ```
   SSH_ASKPASS=./askpass.sh SSH_ASKPASS_REQUIRE=force ssh -o PreferredAuthentications=password \
     -o PubkeyAuthentication=no -p 2900 root@127.0.0.1 \
     "mkdir -p /root/.ssh; echo '<pubkey>' >> /root/.ssh/authorized_keys; chmod 700 /root/.ssh; chmod 600 /root/.ssh/authorized_keys"
   ```
4. A partir de ahí, `ssh -i keys/packer_build_key -p 2900 root@127.0.0.1` ya
   funciona, y se puede correr `scripts/01-base-install.sh` seguido de
   `os/install.sh` manualmente (ver más abajo), o dejar que Packer siga
   desde ahí si todavía está corriendo.

## Ciclo de iteración (dotfiles / paquetes) sobre una VM ya instalada

```
qemu-system-x86_64.exe -M q35 -accel whpx -cpu qemu64 -m 4096 -smp 2 ^
  -drive if=pflash,format=raw,readonly=on,file="C:/Program Files/qemu/share/edk2-x86_64-code.fd" ^
  -drive if=pflash,format=raw,file=output-arch/efivars.fd ^
  -drive file=output-arch/command-os-dev.qcow2,if=virtio,format=qcow2 ^
  -vga std -netdev user,id=net0,hostfwd=tcp::2900-:22 -device virtio-net-pci,netdev=net0 -display none
```

Luego:
```
scp -i keys/packer_build_key -P 2900 -r ../../os root@127.0.0.1:/tmp/command-os/os
ssh -i keys/packer_build_key -p 2900 root@127.0.0.1 '/tmp/command-os/os/install.sh'
```

Y para verificar el checkpoint (sin necesitar ver nada renderizado):
```
ssh -i keys/packer_build_key -p 2900 root@127.0.0.1 \
  'pacman -Q hyprland waybar wofi; systemctl is-enabled seatd NetworkManager sshd; id deck'
```

**Importante**: siempre apagar la VM con `ssh ... "shutdown -h now"` (o
`shutdown` desde la consola) antes de cerrarla, nunca matar el proceso de
QEMU a la fuerza — un corte abrupto de energía puede corromper archivos
recién escritos en el disco (nos pasó con `getty@tty1.service.d/override.conf`,
quedó lleno de bytes nulos tras varios `Stop-Process -Force`).

## Snapshot "clean-base"

Con qcow2, los snapshots son internos al archivo de disco:
```
qemu-img snapshot -c clean-base output-arch/command-os-dev.qcow2   # crear (VM apagada)
qemu-img snapshot -a clean-base output-arch/command-os-dev.qcow2   # restaurar
qemu-img snapshot -l output-arch/command-os-dev.qcow2              # listar
```

## Credenciales de desarrollo (no usar en producto final)

- Usuario: `deck` / password: `deck` (autologin en tty1, arranca Hyprland)
- `root` sin password (deshabilitado con `passwd -d`), solo acceso por la
  llave SSH efímera de `build/packer/keys/`, con `PermitRootLogin yes` —
  revisar/cerrar esto antes de considerar cualquier imagen "shippable".

## Imagen x86 (USB / bare metal)

```
wsl -d archlinux -u root -- bash -c 'DEV_SSH_PUBKEY=/root/vm/devkey.pub \
  setsid nohup bash /mnt/c/Workspace/command/command-os/build/x86/build-image.sh \
  > /root/vm/build.log 2>&1 < /dev/null &'
wsl -d archlinux -u root -- sh /mnt/c/Workspace/command/command-os/build/x86/run-vm.sh
```
`DEV_SSH_PUBKEY` (opcional, solo pruebas en VM) instala esa llave en
`~deck/.ssh`; sin él, la imagen no lleva llaves. SSH: `ssh -i
/root/vm/packer_build_key -p 2901 deck@127.0.0.1`. La build tarda ~20 min
(descarga ~800 MB). La imagen resultante se graba con `dd` a un USB.

## VM de VirtualBox (`command-os-x86`) — ajustes para que vaya fluida

Valores aplicados con `VBoxManage modifyvm command-os-x86` (VM apagada):
`--cpus 1 --memory 6144 --paravirt-provider kvm --graphicscontroller vboxsvga --vram 128
--audio-driver default --audio-controller ac97 --audio-codec ad1980 --audio-enabled on --audio-out on`.

- **1 vCPU es obligatorio.** Con 2 vCPU el firmware EFI se cuelga en `DXE_AP` (se volvió a
  comprobar el 2026-10-01: sin SSH tras 5 min y captura 0x0). `--x2apic off` no lo arregla (VirtualBox
  no deja desactivar el APIC en invitados de 64 bits).
- Hyprland renderiza **por software** en esta VM (aquamarine: "Can't create renderer, no matching
  devices"), a 1024x768. El coste lo pone la CPU, no la GPU: más RAM no acelera nada. Para animaciones
  a pleno rendimiento hay que usar bare metal o el Pi.
- `install.sh` detecta la VM (`systemd-detect-virt`) y escribe `~/.config/hypr/local.conf` con un perfil
  ligero (animaciones de escritorio más cortas, sin transición de borde ni dim).
- Variante de paquetes `COMMAND_OS_VARIANT=vbox`: añade `virtualbox-guest-utils` y habilita
  `vboxservice`.
- Audio: **usar AC97, no HDA**. Con `--audio-controller hda` el reloj del dispositivo no avanza y `pw-play`/`aplay` se cuelgan para siempre. Con AC97 (`snd-intel8x0`) suena bien; sale por el dispositivo de audio por defecto de Windows. PipeWire se
  activa por socket (`systemctl --global enable pipewire.socket pipewire-pulse.socket wireplumber.service`).
- SSH sin avisos de huella: `ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR`.
- Apagado limpio: `ssh ... 'echo deck | sudo -S systemctl poweroff'`.

## Sonidos del sistema

`build/make-sounds.py` genera `os/branding/sounds/*.wav` (síntesis propia, estéreo 48 kHz).
`os/bin/command-os-sound <nombre>` los reproduce con `pw-play`. Eventos: `boot` (inicio de sesión),
`notify`/`critical` (Mako), `lock`/`unlock` (Hypridle), `tick` (teclas de volumen).
