# Ciclo de pruebas en la VM de desarrollo (x86_64, QEMU)

> **El escritorio es labwc.** La VM para probarlo es la de VirtualBox (más abajo), donde renderiza
> por software sin problemas. Cómo probarlo sin ratón: sección "labwc en la VM" al final. QEMU sirve
> sobre todo para validar el instalador.

## Las pruebas de la CI en WSL

`build/wsl/pruebas.sh` lanza en el Arch de WSL las mismas pruebas que `pruebas.yml`: scripts
(sintaxis y shellcheck), marca, pantallas, barra, ajustes, aplicaciones, ligereza, instalador, discos y
rollback. Resumen
final con bien / FALLA / saltada (falta una herramienta) y salida distinta de 0 si algo no está en verde.
Se puede pasar una lista (`… pruebas.sh marca rollback`). Desde PowerShell, siempre con el script en archivo:

```
wsl -d archlinux -u root -- bash /mnt/c/Workspace/command/command-os/build/wsl/pruebas.sh
```

Paquetes del Arch de WSL: `gptfdisk dosfstools ntfsprogs cryptsetup busybox btrfs-progs gettext
shellcheck` (en Arch `mkntfs` está en `ntfsprogs`, no en `ntfs-3g`). **No lanza** las del escritorio
(`escritorio`, `cuentas`, `idioma`, `zona-horaria`, `actualizaciones`): necesitan el paquete instalado y
`cuentas.sh` crea cuentas; esas corren solo en la CI (`escritorio.yml`).

## Medir la ligereza

Cada cambio que pueda pesar (un paquete, un servicio, un módulo de la barra, el compositor) se mide antes y
después con el mismo método (`AGENTS.md` § «Ligereza»), y la cifra se apunta en `docs/medidas/`. Desde el
anfitrión, con la VM `command-os-x86` apagada o encendida:

```
bash build/x86/medir-vm.sh --instalar --nota "qué cambió"
```

Reinicia la VM 3 veces (`-n` para cambiarlo), mide en cada arranque con `os/bin/command-os-medir` (el de este
árbol) y apunta la mediana en `docs/medidas/registro.tsv` y el detalle de los 12 programas que más ocupan en
`docs/medidas/procesos.tsv`, con la fecha, el commit (`+cambios` si `os/` tiene algo sin commit) y la
versión del paquete. `--instalar` instala antes el paquete de este árbol; sin él, mide lo que ya tenga la
VM. Tarda unos 5 min por arranque. `--sin-registro` solo enseña las cifras. Columnas: `docs/medidas/README.md`.

Qué hace `command-os-medir` (también sirve en un PC: `sudo command-os-medir`):
- Espera a que estén el compositor (labwc o Hyprland) y Waybar, y **120 s más desde ese momento**
  (`--espera`; si ya pasaron, no espera): lo que se lanza al entrar ya ha terminado y el bloqueo por
  inactividad (5 min) aún no ha llegado. hyprlock abierto suma unos 300 MB en la VM: una medida con la
  pantalla bloqueada no vale.
- Memoria: la usada (`MemTotal − MemAvailable`) y, por programa, **PSS** (la memoria compartida se reparte
  entre quienes la usan, así que la suma es la memoria real) y RSS (con la compartida entera, como la
  enseña `ps`). Los intérpretes van con el nombre del script (`pantallas.py`), los hilos del núcleo juntos.
- CPU: tics durante 60 s (`--ventana`) de todo el sistema (sin idle ni iowait) y de los procesos. **En la
  VM manda la cifra de los procesos**: casi todo lo del sistema son interrupciones del reloj de VirtualBox,
  que no dependen de Command OS.
- Arranque: segundos desde que arranca el núcleo hasta el escritorio (inicio del último de compositor y
  Waybar) y los tiempos de `systemd-analyze` (núcleo, initrd, userspace).
- No cuenta su propia sesión ni lo que la lanzó (sudo, el intérprete, SSH); la terminal del escritorio sí.

Las cifras de la VM solo se comparan con otras de la VM (render por software, sin wi-fi ni Bluetooth); las
de un PC, con las del mismo PC. La prueba del método es `tests/ligereza.sh` (un `/proc` de mentira).
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
`notify`/`critical` (swaync, por urgencia), `lock`/`unlock` (Hypridle), `tick` (teclas de volumen).

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
- **Teclas multimedia y clic derecho**: un dispositivo virtual de `/dev/uinput` (Python con `fcntl.ioctl`,
  sin instalar nada: `UI_SET_EVBIT/KEYBIT/RELBIT`, `UI_DEV_CREATE`, y eventos `input_event`). Teclas:
  113 silencio, 114 y 115 volumen, 224 y 225 brillo. Clic derecho: llevar el puntero a la esquina con
  movimientos relativos (`REL_X/REL_Y`), mover hasta el punto y pulsar `BTN_RIGHT` (0x111). Va como root
  (`sudo`). VirtualBox no tiene retroiluminación: del brillo solo se ve que el OSD recibe la orden
  (`labwc.log`: «BrightnessCtl Backend»). **El puntero virtual se acelera** y no llega adonde se pide
  (un clic en la esquina de una ventana cayó en el botón de energía): para manejar ventanas, el
  teclado (Tab y Intro con `keyboardputscancode 0f 8f` / `1c 9c`; Alt+Tab `38 0f 8f b8`). Los paneles
  GTK se abren desde una terminal de la sesión (Super+Intro y `sh archivo.sh` con la orden: con
  `keyboardputstring` solo salen bien letras, cifras, espacios y el punto), no por SSH: polkit solo
  autentica y deja comprobar actualizaciones a la sesión local activa.
- **Tocar un botón exacto** (2026-10-19): una pantalla táctil virtual de uinput (`EV_ABS` con `ABS_X`/`ABS_Y`
  del tamaño de la pantalla, `BTN_TOUCH` e `INPUT_PROP_DIRECT`, como root) toca en las coordenadas de la
  captura sin la aceleración del ratón. GTK lo toma como un clic. Un toque no da el foco del teclado a la
  ventana (labwc): después, `wtype` sigue escribiendo en la que lo tenía.
- **Inactividad**: bloquea a los 5 min y apaga la pantalla a los 10 (`wlopm` la muestra `on`/`off`). Un
  `ssh` largo se corta: lanzar un script con `setsid nohup` que apunte `wlopm` y `pgrep hyprlock` cada
  5 s en un archivo y mirarlo después. Una tecla la enciende (queda bloqueada hasta teclear la contraseña).
- **Portapapeles**: `wl-copy` por SSH se queda esperando (hay que lanzarlo con `>/dev/null 2>&1`). Super+V
  (`wtype` o `keyboardputscancode e0 5b 2f af e0 db`) abre el historial. Con el buscador o el
  portapapeles abiertos, otro `command-os-clipboard` solo lo cierra (es un interruptor).
- **sudo por SSH**: `echo deck | sudo -S` con la entrada estándar ocupada (un `tar` por la tubería, o
  un `install.sh` que vuelve a pedir sudo dentro) cuenta como contraseña mal puesta; a los tres
  intentos, faillock bloquea sudo 10 minutos (`faillock --user deck` lo enseña). Copiar y ejecutar
  en llamadas de SSH separadas.
- **Probar paneles sin cerrar la sesión**: `greeter.py` y `primer-arranque.py` se pueden abrir en la
  sesión de labwc para una captura (solo hablan con greetd o tocan el sistema al terminar). Para
  bloquear con hypridle parado, `command-os-lock` directamente (`loginctl lock-session` lo atiende
  hypridle).
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

### Asistente de primer arranque en la VM (en `command-os-instalador`)

Para ver el asistente con un disco que ya tiene cuenta, sin tocar el disco real: **instantánea con la VM
apagada** (`snapshot take`) y, al terminar, `snapshot restore` + `snapshot delete`.

1. Arrancar el USB en vivo (con `usb.vdi` y `cidata.vdi` conectados; el firmware arranca antes el disco
   instalado: Esc al encender → Boot Manager → la entrada del USB, la anterior a la de CIDATA).
2. En el USB: `cryptsetup open /dev/sdb5 cos` (contraseña del disco), montar con `-o subvol=@`, borrar
   `/var/lib/command-os/configurado` y cambiar `/etc/command-os/greetd.toml` a
   `command-os-primer-arranque` con `user = "root"`. Para controlarlo sin consola: la llave de
   `build/packer/keys/packer_build_key.pub` en `/root/.ssh/authorized_keys`, `root:*:` en `shadow` y
   `sshd.service` activado (SSH en `127.0.0.1:2903`). Si el sistema es antiguo, `install.sh` encima
   (puede haber un `db.lck` viejo en `/var/lib/pacman`).
3. Desconectar `usb.vdi` y `cidata.vdi`, arrancar, teclear la contraseña del disco y ya sale el asistente.
   Dentro, como root: `XDG_RUNTIME_DIR=/run/user/0 WAYLAND_DISPLAY=wayland-0 wlr-randr --output VGA-1
   --custom-mode 1024x600` y `grim captura.png`. La rueda (para probar el desplazamiento) se simula con
   `/dev/uinput` (`REL_WHEEL`, como las teclas en «labwc en la VM»).
