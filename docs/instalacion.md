# Instalar Command OS en un PC (x86_64)

> Todas las formas de instalar (PC, máquina virtual, Arch ya instalado, imagen USB…), con los pasos
> para quien instala: [`INSTALAR.md`](../INSTALAR.md). Aquí, el detalle del instalador para PC.

Dos formas, con el mismo asistente (`build/x86/instalar.sh`) desde un USB de Arch Linux:

| | Junto a Windows (dual boot) | Como sistema principal |
| --- | --- | --- |
| Qué pasa con lo que hay | Windows y sus archivos se quedan | **Se borra el disco entero** |
| Al encender | Menú: Command OS o Windows | Arranca Command OS |
| Antes, en Windows | Liberar ≥ 30 GB, BitLocker, inicio rápido ([`dualboot.md`](dualboot.md)) | Copiar lo que quieras conservar |
| Script | `install-dualboot.sh` | `install-disco.sh` |

En los dos: disco cifrado si se quiere (sí por defecto; [`cifrado.md`](cifrado.md)), raíz en btrfs
con instantáneas (volver atrás desde el menú de arranque o con `command-os-rollback`), el Arch de la
fecha validada y, al encender, el asistente de primer arranque para crear tu cuenta
([`cuentas.md`](cuentas.md)). Las actualizaciones llegan después solas
([`actualizaciones.md`](actualizaciones.md)).

Hace falta: un USB de ≥ 2 GB (se borra), internet (cable o wifi) y un disco de ≥ 30 GB.

## 1. Antes de empezar

- **Haz copia de lo importante.** En el modo sistema principal todo el disco se pierde.
- **Dual boot:** sigue los pasos de Windows de [`dualboot.md`](dualboot.md) § 1 (BitLocker, inicio
  rápido y liberar espacio).
- **USB de Arch Linux:** descarga la ISO de <https://archlinux.org/download/> y grábala con
  [Rufus](https://rufus.ie) (esquema GPT, destino UEFI, modo imagen DD si lo pregunta).
- **BIOS/UEFI** (F2, F10, Supr o Esc al encender): **Secure Boot desactivado**, arranque **UEFI** (sin
  CSM/Legacy) y arrancar desde el USB (menú de arranque: F12, F9, F8 o Esc según la marca).

## 2. En el USB de Arch (consola en vivo)

```sh
loadkeys es                       # teclado español en la consola
iwctl                             # solo wifi: station wlan0 connect "NombreDeLaRed", luego exit
curl -fLO https://github.com/command-designs/command-os-versions/releases/download/instalador/instalar-command-os.sh
bash instalar-command-os.sh
```

`instalar-command-os.sh` descarga el instalador publicado y **comprueba que está firmado con la clave
de Command OS** (la huella va escrita en el script) antes de ejecutar nada; si la firma no es buena,
no hace nada. No hace falta cuenta de GitHub ni token. El equipo instala el paquete `command-os` firmado
del repositorio público, el mismo del que se actualizará. Cómo se publica: [`actualizaciones.md`](actualizaciones.md) § 6.

Desde un clon del repositorio (desarrollo, VM de pruebas), `bash command-os/build/x86/instalar.sh`
hace lo mismo pero construye el paquete desde el árbol `os/`.

El asistente pregunta:

1. **Cómo instalar:** junto a Windows o como sistema principal.
2. **En qué disco:** enseña los discos del equipo con su tamaño y modelo. El USB de instalación no
   aparece. En el modo sistema principal, los discos que no se pueden usar salen sin número y con el
   motivo.

Después, el instalador elegido pregunta si **cifrar el disco** (sí por defecto) y, si sí, la
contraseña del disco y la **clave de recuperación**, que hay que apuntar ([`cifrado.md`](cifrado.md)).
Por último enseña el disco y lo que contiene y pide confirmación: hasta ahí no se ha tocado nada.
Tarda 10–20 min (descarga unos 2 GB). Al terminar: `reboot` y quita el USB cuando se apague la pantalla.

Opciones (variables antes del comando, ej. `KB_LAYOUT=us bash instalar-command-os.sh`): `KB_LAYOUT` (teclado, `es`),
`TIMEZONE` (`Europe/Madrid`), `HOSTNAME_NEW` (`command-os`), `VARIANT` (`pc-nvidia` si hay GPU
NVIDIA, solo; vacío en Intel/AMD) y `CIFRADO` (`si`/`no`: no pregunta si cifrar).

## 3. Qué protege al instalador del disco entero

Borrar un disco no tiene vuelta atrás, así que `install-disco.sh` **no toca nada** hasta que todo esto
se cumple (`build/x86/lib.sh`, probado en `tests/discos.sh` en cada cambio):

- Se ejecuta **desde el USB en vivo de Arch**; en un sistema ya instalado se niega.
- El disco se indica siempre a mano; no hay disco por defecto.
- Se niega con: el USB de instalación (aunque se haya copiado a la memoria), el disco del sistema en
  marcha, un disco con particiones montadas, swap en uso, LVM/RAID/cifrado abierto, una partición en
  vez de un disco, un disco de solo lectura o de menos de 30 GB.
- Enseña modelo, tamaño, número de serie y particiones, y avisa si hay **Windows**.
- La confirmación es **escribir el nombre exacto del disco** (por ejemplo `/dev/nvme0n1`); si tiene
  Windows, además `BORRAR WINDOWS`. Un Intro, un «sí» o el nombre de otro disco cancelan sin tocar nada.
- Solo ese disco se modifica: los demás discos del equipo no se tocan.

## 4. Cómo queda el disco (sistema principal)

| Partición | Tamaño | Qué es |
| --- | --- | --- |
| 1 | 1 GiB, FAT32 (`/efi`) | GRUB: entrada `command-os` en la NVRAM del equipo y el arranque de reserva `EFI/BOOT/BOOTX64.EFI` (arranca aunque la BIOS pierda la entrada) |
| 2 | el resto, btrfs | subvolúmenes `@` (sistema y kernel), `@home`, `@snapshots`, `@var_log`, `@pkg` |

Con el disco cifrado:

| Partición | Tamaño | Qué es |
| --- | --- | --- |
| 1 | 1 GiB, FAT32 (`/efi`) | GRUB, igual que sin cifrar |
| 2 | 1 GiB, ext4 (`/boot`), **sin cifrar** | kernel, initramfs y `/boot/grub`: GRUB no descifra, la contraseña se pide en el splash |
| 3 | el resto, LUKS2 | btrfs con los mismos subvolúmenes (`@` ya sin el kernel) |

Sin swap. Detalle del cifrado, la clave de recuperación y las instantáneas: [`cifrado.md`](cifrado.md).

## 5. Primer arranque y problemas

- Disco cifrado: la contraseña del disco (o la clave de recuperación) en la pantalla de arranque.
- Sale el asistente de primer arranque: cuenta, contraseña y si quieres entrar sin contraseña.
- Wifi: el icono de red de la barra o `nmtui` en una terminal.
- **No arranca Command OS** (vuelve al USB o a «no hay sistema»): en la BIOS, pon `command-os` (o el
  disco) primero en el orden de arranque.
- Dual boot: problemas conocidos en [`dualboot.md`](dualboot.md).

## Probar sin instalar

`build/x86/build-image.sh` hace una imagen que se graba en un USB y arranca Command OS desde él, sin
tocar el disco del equipo (desarrollo y demostraciones; `docs/notas/arranque-e-imagenes.md`).

## Cómo se ha probado

En la VM de VirtualBox `command-os-instalador` (`docs/testing.md`): la ISO de Arch como disco USB, un
disco vacío de 40 GB y un disco señuelo con archivos. El instalador rechaza el USB, el señuelo y las
confirmaciones malas; instala en el disco vacío, arranca desde él (asistente de primer arranque) y se
actualiza; la huella del señuelo es la misma antes y después. Después, en el mismo disco, una tabla como
la de Windows (EFI con `bootmgfw.efi`, MSR, NTFS y hueco libre) y el dual boot: Windows queda igual
(tabla, NTFS, archivos de la EFI y su arranque de reserva), el menú de GRUB tiene Command OS, Windows e
instantáneas, y la entrada UEFI apunta a la partición nueva. Con el disco cifrado, los dos modos y la
vuelta atrás: [`cifrado.md`](cifrado.md).

Instalador publicado (2026-10-07): `tests/instalador.sh` en cada cambio (huella, contenido, y que no
ejecuta nada con la firma alterada, sin firma o de otra clave) y, en la misma VM, el USB en vivo **sin
clon del repositorio**: `instalar-command-os.sh` comprobó la firma (clave de prueba), instaló en disco
entero el paquete publicado validado por firma (`pacman -Qi`: «Signature») y arrancó hasta el asistente.
**No se ha probado en un PC real.**
