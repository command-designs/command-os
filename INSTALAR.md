# Instalar Command OS

Todas las formas de tener Command OS, de la más habitual a la más técnica. El detalle de cada pieza
está en `docs/` (enlazado en cada apartado).

| Forma | Para qué | Qué hace falta | Estado |
| --- | --- | --- | --- |
| [1. En un PC, junto a Windows](#1-en-un-pc-desde-un-usb-recomendado) | Usar Command OS y conservar Windows | USB ≥ 2 GB, internet, ≥ 30 GB libres | Probado en VM |
| [1. En un PC, disco entero](#1-en-un-pc-desde-un-usb-recomendado) | Command OS como único sistema | USB ≥ 2 GB, internet, disco ≥ 30 GB (se borra) | Probado en VM |
| [2. En una máquina virtual](#2-en-una-máquina-virtual-virtualbox) | Probarlo sin tocar el PC | VirtualBox, 4 GB de RAM, 40 GB de disco | Probado |
| [3. Sin el asistente](#3-sin-el-asistente-directo-a-un-disco) | Instalaciones repetidas o guiadas por soporte | Lo mismo que 1 | Probado en VM |
| [4. Sobre un Arch Linux ya instalado](#4-sobre-un-arch-linux-ya-instalado-avanzado) | Quien ya usa Arch | Arch x86_64 instalado | Sin probar |
| [5. Desde el código](#5-desde-el-código-desarrollo) | Desarrollo | Acceso al repositorio privado | Probado en VM |
| [6. Imagen USB para probar](#6-imagen-usb-para-probar-sin-instalar-desarrollo) | Demostraciones, arrancar sin instalar | WSL con Arch, USB ≥ 16 GB | Probado en VM |
| [7. Raspberry Pi / ARM](#7-raspberry-pi-y-otras-placas-arm) | El cyberdeck | — | Aún no |

Ninguna forma se ha probado todavía en un PC real: lo prueba el usuario (`ROADMAP.md`).

---

## 1. En un PC desde un USB (recomendado)

Instala Command OS **junto a Windows** (dual boot: al encender eliges) o **en el disco entero**
(borra todo lo que tenga). En los dos casos: disco cifrado si quieres (sí por defecto), instantáneas
para volver atrás y actualizaciones automáticas. No hace falta cuenta de GitHub ni nada más.

### 1.1 Antes de empezar

1. **Copia de seguridad** de lo importante. En el modo disco entero se pierde todo.
2. **Solo junto a Windows**, en Windows ([`docs/dualboot.md`](docs/dualboot.md) § 1):
   - Si el disco tiene **BitLocker**, apunta la clave de recuperación (aka.ms/myrecoverykey).
   - Desactiva el **inicio rápido** (Panel de control → Opciones de energía).
   - Libera **≥ 30 GB**: Administración de discos → clic derecho en `C:` → Reducir volumen. Deja el
     hueco sin asignar (no crees ninguna partición).
3. **USB de Arch Linux**: descarga la ISO de <https://archlinux.org/download/> y grábala:
   - En Windows, con [Rufus](https://rufus.ie): esquema **GPT**, destino **UEFI**, modo **imagen DD**
     si lo pregunta.
   - En Linux o macOS: `sudo dd if=archlinux-*.iso of=/dev/sdX bs=4M status=progress oflag=sync`
     (`/dev/sdX` = el USB; comprueba con `lsblk` que es él: el disco que pongas se borra).
4. **BIOS/UEFI** (F2, F10, Supr o Esc al encender): **Secure Boot desactivado** y arranque **UEFI**
   (sin CSM/Legacy). Arranca desde el USB con el menú de arranque (F12, F9, F8 o Esc según la marca).

### 1.2 En el USB de Arch

En la consola que aparece (ya eres root):

```sh
loadkeys es                # teclado español
iwctl                      # solo con wifi: station wlan0 connect "NombreDeLaRed", luego exit
curl -fLO https://github.com/command-designs/command-os-versions/releases/download/instalador/instalar-command-os.sh
bash instalar-command-os.sh
```

`instalar-command-os.sh` descarga el instalador y **comprueba que está firmado con la clave de Command
OS** antes de ejecutar nada (si no, no hace nada). Después pregunta:

1. **Cómo instalar:** `1` junto a Windows, `2` disco entero.
2. **En qué disco:** enseña los discos con tamaño y modelo. El USB no aparece y, en disco entero, los
   que no se pueden usar salen sin número y con el motivo.
3. **Cifrar el disco** (recomendado, sí por defecto): la contraseña del disco (al menos 8 caracteres,
   sin ñ ni tildes) y una **clave de recuperación** de 48 cifras que **tienes que apuntar**: te pide
   dos de sus grupos para comprobarlo. Sin contraseña ni clave, los datos no se recuperan
   ([`docs/cifrado.md`](docs/cifrado.md)).
4. **Confirmación:** enseña el disco y lo que contiene. En disco entero hay que **escribir el nombre
   del disco** (por ejemplo `/dev/nvme0n1`) y, si tiene Windows, `BORRAR WINDOWS`. Hasta aquí no se
   ha tocado nada.

Tarda 10–20 min (descarga unos 2 GB). Al terminar: `reboot` y quita el USB.

**Opciones** (antes del comando, por ejemplo `KB_LAYOUT=us bash instalar-command-os.sh`):

| Variable | Qué cambia | Por defecto |
| --- | --- | --- |
| `KB_LAYOUT` | Teclado de la consola y de la contraseña del disco | `es` |
| `TIMEZONE` | Zona horaria | `Europe/Madrid` |
| `HOSTNAME_NEW` | Nombre del equipo en la red | `command-os` |
| `VARIANT` | `pc-nvidia` (drivers NVIDIA), `vbox` (VirtualBox) o vacío (Intel/AMD) | `pc-nvidia` si detecta GPU NVIDIA |
| `CIFRADO` | `si` / `no`: no pregunta si cifrar | pregunta |

### 1.3 Primer arranque

1. Con el disco cifrado, la contraseña del disco (o la clave de recuperación) en la pantalla de
   arranque.
2. El **asistente de primer arranque**: idioma (castellano o inglés), teclado, tu nombre, usuario,
   contraseña y si quieres entrar sin contraseña al encender ([`docs/cuentas.md`](docs/cuentas.md)).
3. Wifi: el icono de red de la barra o `nmtui` en una terminal.

Las **actualizaciones** llegan solas: la barra avisa y se instalan con `command-os-update`. Si una
actualización sale mal, **Esc** al encender muestra el menú con las instantáneas para volver atrás
([`docs/actualizaciones.md`](docs/actualizaciones.md)).

Problemas: [`docs/instalacion.md`](docs/instalacion.md) § 5 y [`docs/dualboot.md`](docs/dualboot.md)
(problemas conocidos).

### 1.4 Comprobar el instalador a mano (opcional)

`instalar-command-os.sh` ya comprueba la firma del instalador. Para comprobar también el propio
script antes de ejecutarlo:

```sh
U=https://github.com/command-designs/command-os-versions/releases/download/instalador
curl -fLO $U/instalar-command-os.sh -fLO $U/instalar-command-os.sh.sig -fLO $U/command-os.gpg
gpg --import command-os.gpg
gpg --verify instalar-command-os.sh.sig instalar-command-os.sh
```

Tiene que decir «Good signature» de la clave con huella
`B2A6 80DD 66E4 2CF2 95DC  40BA 33FF 77E2 4580 D984` (la misma de los paquetes de Command OS). El
aviso de gpg «This key is not certified with a trusted signature» es normal: lo que cuenta es que la
huella coincida.

---

## 2. En una máquina virtual (VirtualBox)

Igual que en un PC, pero en una VM: no toca nada del equipo.

1. VM nueva de tipo **Arch Linux (64-bit)** con:
   - **EFI activado** (Sistema → Placa base → Habilitar EFI).
   - 4 GB de RAM o más, 2–4 CPU y un disco de **40 GB**.
   - Pantalla: controlador **VBoxSVGA**, 128 MB de vídeo, **sin** aceleración 3D.
   - La ISO de Arch en la unidad óptica.
   - Si Windows tiene Hyper-V o WSL2 activos y la VM se cuelga al arrancar con varias CPU: `VBoxManage
     modifyvm <vm> --cpu-hotplug on` ([`docs/testing.md`](docs/testing.md)).
2. Arranca la VM y sigue el § 1.2 con la variante de VirtualBox:

   ```sh
   VARIANT=vbox bash instalar-command-os.sh
   ```

   Elige `2` (disco entero, el disco virtual). El cifrado es opcional (`CIFRADO=no` para no
   escribir la contraseña en cada arranque).
3. Al terminar, apaga, quita la ISO y arranca.

En la VM la pantalla va a 1280x720 con render por software: funciona, pero más lento que en un PC.

---

## 3. Sin el asistente (directo a un disco)

Para quien sabe en qué disco va: los mismos instaladores que llama el asistente, con el disco como
argumento. Siguen comprobando el disco y pidiendo la misma confirmación.

```sh
curl -fLO https://github.com/command-designs/command-os-versions/releases/download/instalador/instalar-command-os.sh
bash instalar-command-os.sh            # descarga y comprueba; en la primera pregunta, cualquier otra tecla cancela
cd /root/command-os-instalador/command-os
lsblk -o NAME,SIZE,MODEL               # identificar el disco
bash build/x86/install-disco.sh /dev/nvme0n1       # disco entero (lo borra)
bash build/x86/install-dualboot.sh /dev/nvme0n1    # junto a Windows (usa el hueco libre)
```

Admiten las mismas variables que el § 1.2.

---

## 4. Sobre un Arch Linux ya instalado (avanzado)

> **Sin probar.** Pensado para quien ya usa Arch x86_64 y quiere convertirlo en Command OS. Haz copia
> de seguridad antes.

Qué cambia en el sistema: instala el paquete `command-os` (escritorio labwc, marca, configuración de
serie), cambia el gestor de inicio de sesión por greetd, pone el arranque silencioso y el tema en
GRUB y, si la raíz es btrfs, configura snapper y las instantáneas en el menú de GRUB. Los archivos de
`/home` no se tocan.

**No lo uses si** tu raíz está en LVM o RAID, o si el disco cifrado se abre con `sd-encrypt` (initramfs
de systemd): con raíz btrfs y GRUB, `install.sh` **reescribe los `HOOKS` de `/etc/mkinitcpio.conf`**
con los de Command OS (udev, `encrypt`, `grub-btrfs-overlayfs`) y el equipo no arrancaría. Tampoco si
arrancas con systemd-boot u otro cargador que no sea GRUB: el menú y las instantáneas son de GRUB.

```sh
# Como root.
U=https://github.com/command-designs/command-os-versions/releases/download/instalador
cd /tmp
curl -fLO $U/command-os-instalador.tar.gz -fLO $U/command-os-instalador.tar.gz.sig -fLO $U/command-os.gpg
gpg --import command-os.gpg
gpg --verify command-os-instalador.tar.gz.sig command-os-instalador.tar.gz   # huella del § 1.4
tar -xzf command-os-instalador.tar.gz

# Seguir con el Arch del día: sin esto, Command OS fija los repositorios a la fecha que ha validado
# y tu sistema, más nuevo, quedaría por delante de ellos.
mkdir -p /etc/command-os && touch /etc/command-os/rolling

# Si usas otro gestor de inicio de sesión (gdm, sddm, lightdm…), desactívalo: greetd lo sustituye.
systemctl disable gdm sddm lightdm 2>/dev/null

COMMAND_OS_PAQUETE=repo bash command-os/os/install.sh
reboot
```

Al arrancar sale el asistente de primer arranque, que crea la cuenta principal (administradora). Tus
cuentas anteriores siguen ahí y se pueden elegir en la pantalla de inicio de sesión.

---

## 5. Desde el código (desarrollo)

Con acceso al repositorio privado `command-designs/command-os`. En el USB de Arch:

```sh
pacman -Sy --noconfirm git
git clone https://github.com/command-designs/command-os.git   # usuario de GitHub y un token de lectura
bash command-os/build/x86/instalar.sh
```

Lo mismo que el § 1, pero **construye el paquete desde el árbol `os/`** en vez de descargar el
publicado: sirve para probar cambios sin publicarlos. Pruebas sin discos reales:
[`docs/testing.md`](docs/testing.md) (VM `command-os-instalador`).

---

## 6. Imagen USB para probar sin instalar (desarrollo)

Una imagen de disco que se graba en un USB y arranca Command OS desde él, sin tocar el disco del
equipo. Se construye desde el código, en WSL con Arch (Windows) o en un Arch:

```sh
# Como root, desde un clon del repositorio. Tarda ~20 min.
bash build/x86/build-image.sh                     # deja /root/vm/command-os-x86.img (14 GB)
dd if=/root/vm/command-os-x86.img of=/dev/sdX bs=4M status=progress oflag=sync   # /dev/sdX = el USB
```

Variables: `VARIANT` (`pc-nvidia` por defecto), `IMG`, `SIZE` y `DEV_SSH_PUBKEY` (solo pruebas: crea
la cuenta `deck`/`deck` con esa llave SSH). Sin cifrado y con zona UTC; al arrancar, el asistente de
primer arranque. Para probarla en una VM: `build/x86/run-vm.sh` (QEMU). Detalle:
[`docs/notas/arranque-e-imagenes.md`](docs/notas/arranque-e-imagenes.md).

---

## 7. Raspberry Pi y otras placas ARM

**Aún no.** Command OS está pensado también para ARM (el cyberdeck), pero se retoma cuando se sepa qué
placa lleva (`ROADMAP.md`, «Aparcado»). Hoy solo se instala en PC x86_64.
