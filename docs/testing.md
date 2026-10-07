# Ciclo de pruebas en la VM de desarrollo (x86_64, QEMU)

> **El escritorio es labwc.** La VM para probarlo es la de VirtualBox (más abajo), donde renderiza
> por software sin problemas. Cómo probarlo sin ratón: sección "labwc en la VM" al final. QEMU sirve
> sobre todo para validar el instalador.

## QEMU: validar el instalador

QEMU con `virtio-gpu` es la herramienta para validar que `os/install.sh` corre sin errores
(paquetes, usuario, dotfiles, servicios, autologin) y la misma que se usará para la arquitectura ARM
(`qemu-system-aarch64`). Para ver y usar el escritorio, la VM de VirtualBox.

- **QEMU nativo de Windows (WHPX)**: valida el instalador. Sin aceleración 3D no hay GBM para el
  compositor; con `virtio-gpu-gl-pci` + `-display sdl,gl=on` la VM cuelga (~100% CPU sin avanzar).
- **QEMU dentro de WSL2 con KVM anidado**: el compositor renderiza (virgl → Mesa d3d12 → GPU del
  host), pero por WSLg o VNC va con lag y Windows se come la tecla Super. Scripts:
  `build/wsl/setup.sh` y `build/wsl/run-vm.sh`; `run-vm.sh` exporta `GALLIUM_DRIVER=d3d12` (sin
  eso Mesa usa `llvmpipe`). Requisitos: WSL2, `%USERPROFILE%\.wslconfig` con
  `nestedVirtualization=true`, `memory=10GB`, `processors=10`, y `wsl --install -d archlinux`.
  Captura desde el guest:
  `su deck -c 'XDG_RUNTIME_DIR=/run/user/1000 WAYLAND_DISPLAY=wayland-0 grim /tmp/shot.png'`.
  Apagar siempre con `ssh ... 'shutdown -h now'` (nunca matar QEMU).
- Los discos QEMU existentes son anteriores a labwc: reconstruirlos antes de usarlos.

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

- Usuario: `deck` / password: `deck` (inicio automático con greetd, sin asistente: lo crea
  `COMMAND_OS_DEV_USER=deck`; ver `docs/cuentas.md`)
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
  solo se ve en bare metal o en el Pi; por eso 720p y no 1080p.
- **Resolución**: si `systemd-detect-virt` es `oracle`, `install.sh` añade `video=1280x720` a la
  línea del kernel (sin eso, `vboxvideo` pone 1024x768). Splash y escritorio van a 1280x720 y labwc
  reutiliza el modo (`<reuseOutputMode>`): sin pantallazo negro al entrar. La ventana de VirtualBox
  está en modo escalado (`GUI/Scale`).
- **Otras resoluciones** (16:9, 16:10, alta densidad, GRUB y splash): `setvideomodehint` no funciona
  aquí; cómo cambiarlas y capturarlas en `docs/notas/pantallas.md` § «Probar resoluciones en la VM».
- **Grabar vídeo**: `VBoxManage modifyvm command-os-x86 --recording=on --recording-screens=0
  --recording-file=<ruta.webm> --recording-video-res=1280x720 --recording-video-fps=25` con la VM
  apagada; graba desde el encendido hasta el apagado. Solo capta lo que va a la resolución de la
  grabación (por eso importa el `video=1280x720`). No graba el audio.
- **Descartado: `vmsvga` + 3D.** Con `--graphicscontroller vmsvga
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
  re-ejecutar con la sesión abierta. Para recargar la
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
- kitty abre siempre a 100x30 celdas (`remember_window_size no`), no con el tamaño de la última.

## Instalador en la VM `command-os-instalador` (2026-10-07)

Para probar `build/x86/instalar.sh` (dual boot y disco entero) de principio a fin **sin tocar ningún
disco real**. Todo vive en `build/x86/vbox/instalador/` (ignorado por git):

- `usb.vdi`: la ISO de Arch convertida en disco (`VBoxManage convertfromraw build/iso/archlinux-x86_64.iso
  usb.vdi`): arranca como un USB de verdad, con la etiqueta `ARCH_AAAAMM` que el instalador rechaza.
- `disco.vdi` (40 GB, vacío): donde se instala. `senuelo.vdi` (4 GB): ext4 con archivos; se toma su
  `sha256sum` antes y se compara después.
- `cidata.vdi`: disco FAT `CIDATA` con `meta-data` y `user-data` de cloud-init (la llave
  `build/packer/keys/packer_build_key.pub` para root). La ISO de Arch trae cloud-init: al arrancar,
  SSH en `127.0.0.1:2903` como root, sin teclear nada en la consola. Se genera en WSL con
  `mkfs.fat -n CIDATA` sobre un archivo y un loop.
- VM: EFI, ICH9, 4 vCPU con `--cpu-hotplug on`, 4 GB, `vboxsvga`, NAT con `2903 → 22`. Puertos SATA:
  0 USB, 1 disco, 2 señuelo, 3 CIDATA. Se instala con `VARIANT=vbox` (utilidades de invitado).
- Copiar el repositorio: `git ls-files -co --exclude-standard os build/x86 | tar -czf - -T - | ssh … 'tar
  -xzf - -C /root/command-os'` (nunca `tar` de `build/x86` entero: arrastra los discos de las VM).
- Tras instalar: apagar, quitar `usb.vdi` y `cidata.vdi` y arrancar. El asistente de primer arranque se
  maneja con `VBoxManage controlvm command-os-instalador keyboardputstring` y capturas
  (`screenshotpng`); después, `VBoxManage guestcontrol … run --username <cuenta>` para mirar dentro.
- **Disco cifrado** (`docs/cifrado.md`): se instala sin teclear con `expect` en el USB en vivo
  (`pacman -Sy expect`), que lee la clave de recuperación de la pantalla y contesta los dos grupos que
  pide. La contraseña del splash se teclea con `keyboardputstring`, que escribe como un teclado de
  EE. UU.: en la VM (teclado español) solo letras, cifras y espacios; la clave de recuperación, sin
  guiones (con espacios sí).
- La NVRAM de la VM pierde la entrada `command-os` al apagarla: arranca por `EFI/BOOT/BOOTX64.EFI`.
  Para volver al USB en vivo con un sistema ya instalado en el disco: dentro de él,
  `efibootmgr -n <la entrada de SATA 0>` y reiniciar.
- Instalar en un disco temporal sin estropear el dual boot de `disco.vdi`: `NO_NVRAM=1` (no toca la
  entrada UEFI del dual boot; el temporal arranca por `EFI/BOOT/BOOTX64.EFI`). Sin él,
  `forget_nvram_entries` borra la del disco que no está conectado y hay que rehacerla desde el USB con
  `efibootmgr -c -d /dev/sdb -p 1 -L command-os -l '\EFI\command-os\grubx64.efi'`.
- Instalador publicado sin la clave real: firmar con una clave de prueba y cambiar `HUELLA` en una
  copia de `instalar-command-os.sh`; `COMMAND_OS_INSTALADOR_URL=file:///root/pub` lo lee de una carpeta.
- Para empezar de cero: cambiar `disco.vdi` por uno vacío. La NVRAM de la VM se queda con la entrada
  `command-os` vieja, que apunta a una partición que ya no existe: así se prueba `forget_nvram_entries`.
- Si `startvm` falla con «The VM session was closed before any attempt to power it on», quedan procesos
  `VBoxHeadless` de una sesión anterior bloqueando `VBoxHardening.log`: cerrar el padre (la VM apagada).
