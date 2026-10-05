# Ciclo de pruebas en la VM de desarrollo (x86_64, QEMU)

> **Desde el 2026-10-05 el escritorio es labwc** (antes Hyprland). Las secciones de QEMU y WSL se
> escribieron con Hyprland y se dejan como historia; hoy la VM de pruebas del escritorio es la de
> VirtualBox (más abajo), donde labwc renderiza por software sin problemas. Cómo probar labwc sin
> ratón: sección "labwc en la VM" al final.

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
su deck -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 grim /tmp/shot.png'
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
  'pacman -Q labwc waybar wofi; systemctl is-enabled seatd NetworkManager sshd; id deck'
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

- Usuario: `deck` / password: `deck` (autologin en tty1, arranca labwc)
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

## VM de VirtualBox (`command-os-x86`) — ajustes para que vaya lo mejor posible

Valores aplicados con `VBoxManage modifyvm command-os-x86` (VM apagada):
`--cpu-hotplug on --cpus 4 --memory 6144 --paravirt-provider kvm --graphicscontroller vboxsvga
--vram 128 --accelerate-3d off --audio-driver default --audio-controller ac97 --audio-codec ad1980
--audio-enabled on --audio-out on`, con las CPU 1-3 enchufadas (`<CpuTree>` del `.vbox` con ids 0-3).
Cierre de ventana = apagado ACPI limpio: `setextradata GUI/DefaultCloseAction Shutdown` y
`GUI/RestrictedCloseActions "SaveState,Detach,PowerOffRestoringSnapshot"`.

- **VirtualBox corre sobre Hyper-V (NEM), no sobre VT-x**, porque WSL2 mantiene el hipervisor de
  Windows activo (`VBox.log`: `HM: HMR3Init: Attempting fall back to NEM: VT-x is not available`).
  De ahí vienen el cuelgue con varias vCPU y la lentitud del render.
- **4 vCPU con CPU hotplug (2026-10-04).** Con `--cpus 2` sin hotplug el firmware EFI se cuelga en
  `DXE_AP`. Con `--cpu-hotplug on` y las CPU enchufadas (`controlvm plugcpu N` o en el `.vbox`) arranca
  bien con 4 y Linux las pone en línea solo (`nproc` = 4); llvmpipe usa 4 hilos.
- labwc renderiza **por software** (llvmpipe) con `vboxsvga` + driver `vboxvideo`. La fluidez real
  solo se ve en bare metal o en el Pi. (Con Hyprland: ~5 FPS a 1080p y ~13 FPS a 720p.)
- **Resolución**: `install.sh` escribe `~/.config/labwc/autostart.local` con
  `wlr-randr … --mode 1280x720` solo si `systemd-detect-virt` es `oracle`. El splash va a 1024x768,
  así que al entrar al escritorio hay ~2 s en negro por el cambio de modo; en hardware real labwc
  reutiliza el modo del splash (`<reuseOutputMode>`). La ventana de VirtualBox está en modo escalado
  (`GUI/Scale`).
- **Descartado: `vmsvga` + 3D** (probado con Hyprland). Con `--graphicscontroller vmsvga
  --accelerate-3d on` carga `vmwgfx` y el compositor arranca sobre la GPU del anfitrión, pero los
  clientes no se muestran. Vuelto a `vboxsvga`.
- `install.sh` detecta la VM (`systemd-detect-virt`) y escribe `~/.config/labwc/themerc-override`
  sin sombras ni halo (cada fotograma cuenta con render por software).
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

## labwc en la VM (2026-10-05)

Comandos desde el anfitrión con `S="ssh -i build/packer/keys/packer_build_key -p 2902 deck@127.0.0.1"`
(más las opciones sin avisos de huella) y `E='export WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run/user/1000;'`:

- **Iterar**: copiar `os/` (`tar -czf - os | $S 'tar -xzf - -C /tmp/command-os'`) y
  `echo deck | sudo -S env COMMAND_OS_VARIANT=vbox bash /tmp/command-os/os/install.sh`. Se puede
  re-ejecutar con la sesión abierta (con Hyprland se colgaba; con labwc no). Para recargar la
  configuración y el tema: `kill -HUP $(pidof labwc)` (`labwc -r` solo funciona dentro de la sesión,
  necesita `LABWC_PID`). Waybar no se recarga solo: `pkill -x waybar` y lanzarlo con `setsid`.
- **Log**: `/run/user/1000/labwc.log` (labwc y todo lo que arranca `autostart`). Son normales el
  aviso de `seatd.sock` (entra por logind), los `EGL_BAD_ALLOC` del render por software y el
  `hyprland-lock-notify-v1` de hypridle (solo afecta a `on_lock_cmd`, que no usamos).
- **Teclado y atajos**: `wtype` (instalarlo solo para la prueba). Super solo:
  `wtype -P Super_L -p Super_L`; combinaciones: `wtype -M logo -k Down -m logo`; Alt+Tab mantenido
  para capturarlo: `nohup wtype -M alt -P Tab -s 300 -p Tab -s 8000 -m alt &`.
- **Bloqueo**: `loginctl lock-session` lanzado por SSH bloquea la sesión SSH; hay que pasar el id de
  la de tty1: `loginctl lock-session $(loginctl list-sessions --no-legend | awk '/tty1/{print $1}')`.
  Desbloquear: `wtype deck; wtype -k Return`.
- **Capturas**: `VBoxManage controlvm command-os-x86 screenshotpng <ruta.png>` (también durante el
  arranque, para ver splash → escritorio).
- **Clic derecho en el escritorio**: no se puede simular sin ratón virtual; el menú `client-menu`
  (Alt+Espacio) usa el mismo tema y sí se puede ver.
- kitty guardaba la ventana maximizada de la época de Hyprland en `~/.cache/kitty/main.json`; ahora
  abre siempre a 100x30 celdas (`remember_window_size no`).
