# Cifrado del disco (LUKS2)

Al instalar en un PC (disco entero o dual boot, [`instalacion.md`](instalacion.md)) el asistente
pregunta **«¿Cifrar el disco? [S/n]»**, con sí por defecto. Con el disco cifrado, nadie puede leer
lo que hay en Command OS sin la contraseña, aunque se lleve el equipo o saque el disco. La imagen USB
de `build-image.sh` no se cifra: es genérica, para probar sin instalar. Por qué se decidió así:
[`decisiones.md`](decisiones.md).

## Qué se pide al instalar

Antes de la confirmación del borrado (después ya no se pregunta nada):

1. **Contraseña del disco**, dos veces. Al menos 8 caracteres y **sin ñ ni tildes**: se teclea al
   encender, antes de que arranque el sistema, y si el teclado no diera esas letras no se podría entrar.
   Antes de pedirla, el instalador pone en la consola la distribución de `KB_LAYOUT` (la que tendrá el
   splash): así una contraseña con símbolos se escribe igual al instalar que al encender.
2. **Clave de recuperación**: 48 cifras en 8 grupos (`412787-352309-…`), generadas en el equipo al azar.
   Se enseñan una sola vez y, para seguir, hay que escribir dos grupos elegidos al azar. Después se
   borran de la pantalla y del historial de la terminal. **No se guarda en ningún sitio**: ni en el
   equipo, ni en el repositorio, ni en ningún servidor.

## Al encender

El menú de GRUB sale como siempre y, en la pantalla de arranque (el splash), donde va la consola de
servicios aparece **«contraseña del disco · o la clave de recuperación»** con un punto por carácter.
Si no es correcta, sale en rojo «contraseña incorrecta · vuelve a escribirla» y se puede volver a
escribir sin límite de intentos. La clave de recuperación se escribe en el mismo campo, con o sin los
guiones o espacios. Esc pasa al modo detalles de Plymouth (texto, para soporte técnico): la pide igual,
aunque ahí el texto sale sin la ñ ni las tildes (consola del initramfs).

**Una sola contraseña al encender.** Con el disco cifrado, el asistente de primer arranque
(`docs/cuentas.md`) propone «entrar sin contraseña al encender» ya activado, con el texto «el disco ya
la pide»: así no se escriben dos contraseñas seguidas. Es solo la propuesta (el interruptor se puede
apagar, o `command-os-login pedir` después). La pantalla sigue bloqueándose con la contraseña de la
cuenta (inactividad, Super+L, tapa), y quien no sepa la del disco no pasa del splash. El asistente
sabe que el disco está cifrado por `cryptdevice=` en la línea del kernel (`comun.disco_cifrado`).

## Si se pierde la contraseña

- Se entra con la **clave de recuperación** y se pone una contraseña nueva (abajo).
- **Sin contraseña ni clave de recuperación, los datos se pierden**: no hay ninguna puerta trasera ni
  forma de recuperarlos. Queda reinstalar (en disco entero, se borra todo).

## Cambiar la contraseña o la clave de recuperación

**Con el panel** (menú del escritorio → ajustes → disco cifrado, `command-os-disco`; solo con el disco
cifrado):

- **Cambiar la contraseña del disco:** pide la contraseña actual del disco y la nueva (dos veces; al
  menos 8 caracteres, sin ñ ni tildes: se teclea antes de que arranque el sistema).
- **Generar una clave de recuperación nueva:** el panel genera 48 cifras, **las enseña una sola vez** y
  hasta que se escriben dos de sus grupos al azar (como en el instalador) no se cambia nada; además pide
  la contraseña actual del disco. La anterior deja de valer.
- Las dos acciones piden también la contraseña de un administrador (polkit, cada vez). Lo hace
  `lib/gestionar-disco`, lanzado con `pkexec`; las contraseñas van por la entrada estándar. El volumen es
  el de `cryptdevice=UUID=…` de la línea del kernel.
- El disco tiene **dos ranuras**: la contraseña en la 0 y la clave de recuperación en otra. La
  contraseña actual tiene que abrir la ranura 0 (si fuera la clave de recuperación, cambiarla
  sustituiría la ranura equivocada). Para la clave nueva se usa una ranura libre, se comprueba que abre
  y solo entonces se quita la vieja: el disco nunca se queda sin una clave de recuperación que
  funcione. Si hay más claves de las dos (puestas a mano), el panel no toca nada y avisa.
- `tests/discos.sh` lo prueba con un LUKS de verdad en un disco loop (contraseña mala, clave de
  recuperación como actual, ñ, claves cortas, ranuras de más…).

**A mano**, en una terminal. La partición cifrada es la de nombre
`command-os` (`lsblk -o NAME,PARTLABEL,FSTYPE`; por ejemplo `/dev/nvme0n1p3`):

```sh
sudo cryptsetup luksChangeKey /dev/nvme0n1p3       # contraseña nueva (pide la actual)
sudo cryptsetup luksAddKey /dev/nvme0n1p3          # añade otra contraseña o clave
sudo cryptsetup luksRemoveKey /dev/nvme0n1p3       # quita la que se escriba (nunca la última)
```

Una clave de recuperación nueva: `tr -dc 0-9 < /dev/urandom | head -c 48` da las cifras; se añade con
`luksAddKey` y se quita la antigua con `luksRemoveKey`.

## Cómo queda el disco

| | Disco entero | Dual boot (en el hueco libre) |
| --- | --- | --- |
| EFI | 1 GiB, nueva (FAT32) | la de Windows, sin formatear |
| `/boot` | 1 GiB, ext4 **sin cifrar** | 1 GiB, ext4 **sin cifrar** |
| Resto | LUKS2 → btrfs con los subvolúmenes de siempre | LUKS2 → btrfs |

- **LUKS2 con argon2id** (lo que más cuesta probar contraseñas a lo bruto) en dos ranuras: la
  contraseña y la clave de recuperación. TRIM activado (`allow-discards`, guardado en la cabecera): a
  cambio, se ve qué zonas del disco están libres, nunca su contenido.
- **`/boot` sin cifrar**, con el kernel, el initramfs y GRUB: así la contraseña se pide en el splash
  (GRUB no descifra nada) y solo una vez. Si GRUB descifrara `/boot`, la pediría él antes del splash,
  en modo texto, y otra vez el sistema.
- `cryptdevice=UUID=…:command-os` va en `GRUB_CMDLINE_LINUX` de `/etc/default/grub` (no en `_DEFAULT`,
  que es de `apply-boot`): lo llevan todas las entradas, también las de las instantáneas.

## Cómo funciona por dentro

- Initramfs: `HOOKS=(base udev plymouth keyboard autodetect … keymap block command-os-cifrado encrypt
  filesystems fsck grub-btrfs-overlayfs)` (`os/install.sh`, si la raíz está sobre LUKS). `keyboard`
  antes de `autodetect` para que entren todos los teclados (uno USB enchufado después también sirve) y
  `keymap` con la distribución de `/etc/vconsole.conf`.
- `command-os-cifrado` (`os/initcpio/`, va en el paquete) pide la contraseña con `plymouth
  ask-for-password` en el idioma del sistema (parámetro `command-os.idioma=` de la línea del kernel,
  que pone `apply-boot`; `docs/idioma.md`) y sin límite de intentos, y abre el volumen. El gancho `encrypt` de
  Arch lo ve abierto y no hace nada: de él solo se usan cryptsetup y los módulos. Sin Plymouth, pregunta
  en la consola. (El `encrypt` de Arch pide en inglés y, tras 3 fallos, deja una consola de emergencia.)
  Si no puede preguntar 5 veces seguidas (Plymouth no atiende, consola sin entrada), cede el paso a
  `encrypt`, que acaba en la consola de emergencia: el arranque nunca se queda colgado en el splash.
- El tema del splash (`command.script`) dibuja el campo en el sitio de la lista de comprobaciones: el
  texto, una línea y un cuadradito hueso por carácter, con el cursor Red Hot. Al abrir el disco, el
  gancho marca «disco del sistema» en curso en la lista (`docs/notas/arranque-e-imagenes.md`). Los dos textos del gancho («contraseña del disco · o la clave de
  recuperación» en Ash, y el de contraseña incorrecta, en Red Hot) son **imágenes** en JetBrains Mono, una por
  idioma (`texto-clave.es.png`, `.en.png`…; `build/make-plymouth-textos.py`, con los textos de
  `os/po/`): en el initramfs Plymouth solo tiene `label-freetype`, que sin un locale UTF-8 pinta la ñ
  y las tildes como cuadrados. El tema elige la imagen por el texto que manda el gancho («del disco» e
  «incorrecta»; «Disk password» y «Wrong password»): si se cambian, cambiar los dos. Cambiar de idioma
  no rehace el initramfs: solo la línea del kernel (GRUB).
- El busybox del initramfs es el reducido de mkinitcpio: **no tiene `tr` ni `stty`**. El gancho solo usa
  shell, `cryptsetup` y `plymouth`; `tests/discos.sh` lo ejecuta con un `PATH` que solo tiene eso.

## Instantáneas y volver atrás

Con `/boot` aparte, **el kernel no entra en las instantáneas** (sin cifrar sí, porque va en `@`):

- **`command-os-rollback`** lo compensa: pone en `/boot` el kernel de la instantánea (Arch lo guarda
  junto a sus módulos en `/usr/lib/modules/<versión>/vmlinuz`; solo el que es de un paquete) y rehace
  su initramfs con la configuración del sistema recuperado. Si es el mismo kernel que ya hay en `/boot`,
  no toca nada. Si algo falla, deja el sistema como estaba.
- **Arrancar una instantánea desde el menú** (Esc → instantáneas) usa el kernel de `/boot`, el más
  nuevo. Si se actualizó el kernel después de la instantánea, arranca con lo que hay en el initramfs
  (disco, pantalla, teclado) pero sin los demás módulos (wifi, sonido): basta para lanzar
  `command-os-rollback`, que deja kernel y módulos a juego para el siguiente arranque.

## Cómo se ha probado

- `tests/discos.sh` (en cada cambio, discos loop): preguntas, contraseña y clave de recuperación,
  particiones, LUKS2/argon2id/TRIM, dos ranuras, que abre con la contraseña y con la clave y no con una
  mala, y el gancho del initramfs (con bash y con el ash de busybox): tras una mala, abre con la clave
  de recuperación con guiones.
- VM `command-os-instalador` (`docs/testing.md`, 2026-10-07), instalando con `expect` como una persona:
  - **Disco entero cifrado**: EFI, `/boot` ext4 y LUKS2 (argon2id en las dos ranuras, TRIM); el
    señuelo, intacto. Al arrancar: el campo en el splash, una contraseña mala en rojo, la clave de
    recuperación sin separadores y con espacios, la contraseña normal y el asistente de primer
    arranque. Dentro: ganchos en orden, `cryptdevice=` en el menú y en las entradas de instantáneas.
  - **Volver atrás con otro kernel**: actualizar de 7.2.8 a 7.2.9 (snap-pac guarda la instantánea antes)
    y `command-os-rollback` a esa instantánea: `/boot` vuelve al 7.2.8 y el sistema recuperado arranca
    con sus módulos (vídeo, sonido, VirtualBox). En disco entero y en dual boot; volver otra vez a la
    misma instantánea (mismo kernel) no rehace nada.
  - **Dual boot cifrado** junto a una tabla como la de Windows (EFI con `bootmgfw.efi`, MSR, NTFS):
    Windows queda igual (tabla, MSR, NTFS y los archivos de su EFI); menú de GRUB con su tema, desde el
    `/boot` sin cifrar, y la entrada de Windows; Esc en el campo pasa al modo detalles y la pide igual.
- VM `command-os-instalador` (2026-10-20), instalación cifrada nueva con `expect` y cambio de claves con
  `lib/gestionar-disco` (lo que lanza el panel, como root por SSH): tras cambiar la contraseña y la clave
  de recuperación, el splash rechaza en rojo la contraseña vieja y la clave vieja; arranca con la
  contraseña nueva y, en otro reinicio, con la clave nueva. `cryptsetup --test-passphrase` confirma que
  las viejas ya no abren y las nuevas sí.
- **Sin probar**: un PC real (teclado USB distinto, contraseña con símbolos, gráfica NVIDIA en el
  splash; lo prueba el usuario) y arrancar una instantánea desde el menú con un kernel más nuevo que ella.
