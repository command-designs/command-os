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
- Hyprland renderiza **por software** (llvmpipe) con `vboxsvga` + driver `vboxvideo`. Medido con
  `debug:overlay`: ~180 ms por fotograma a 1920x1080 (~5 FPS) y ~77 ms a 1280x720 (~13 FPS). La
  fluidez real solo se ve en bare metal o en el Pi.
- **Resolución**: `install.sh` fija `hl.monitor({ mode = "1280x720@60" … })` en `local.lua` solo si
  `systemd-detect-virt` es `oracle`. **No cambiar el modo en caliente** (`hyprctl keyword monitor`):
  Hyprland se cuelga con `vboxvideo`. La ventana de VirtualBox está en modo escalado (`GUI/Scale`).
- **Descartado: `vmsvga` + 3D.** Con `--graphicscontroller vmsvga --accelerate-3d on` carga `vmwgfx`,
  aparece `renderD128` y Hyprland arranca con GLES 3.0 sobre la GPU del anfitrión, pero los clientes
  no se muestran: hyprpaper muere con `invalid arguments for wl_surface#N.attach`, Waybar y Kitty no
  aparecen. Vuelto a `vboxsvga`.
- `install.sh` detecta la VM (`systemd-detect-virt`) y escribe `~/.config/hypr/local.lua` con un perfil
  ligero (animaciones de escritorio más cortas, sin halo, sin giro ni transición de borde, sin dim).
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

## Hyprland con configuración Lua (2026-10-04)

Desde Hyprland 0.56 la configuración es `~/.config/hypr/hyprland.lua` (el `.conf` desaparece en 0.57).
`hyprctl dispatch` ya no acepta la sintaxis antigua: hay que pasar un dispatcher Lua, por ejemplo
`hyprctl dispatch 'hl.dsp.focus({ workspace = 2 })'` o `hyprctl dispatch 'hl.dsp.exec_cmd("kitty")'`.
`hyprctl configerrors` muestra los errores de la configuración. Para simular clics en la VM sirve
`ydotool` (instalarlo solo para la prueba): mover el puntero con
`hyprctl dispatch 'hl.dsp.cursor.move({ x = 135, y = 14 })'` y luego `ydotool click 0xC0`.
