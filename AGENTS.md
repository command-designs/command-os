# Command OS — contexto para retomar el proyecto

## Qué es esto

Distro propia para un cyberdeck comercial, construida como capa de curación
(labwc/Wayland, theming, apps por defecto, instalador) sobre Arch Linux
ARM en el hardware real (Raspberry Pi 5) — modelo Omarchy, pero sobre una
base aarch64 oficial en vez de x86_64. Un colega hace el hardware, este repo
es la parte de software/SO. Ver `README.md` para la estructura del repo.

**Prioridad: x86** (decisión del usuario, 2026-10-07). Todavía no se sabe qué hardware ARM llevará
el cyberdeck, así que se trabaja y se prueba en x86_64 (PC y VM). Command OS sigue siendo para las
dos arquitecturas (paquete `any`, scripts sin nada propio de x86 si no hace falta), pero **no se hace
nada específico de hardware ARM** (Raspberry Pi 5, `cmdline.txt`, imagen ARM) hasta tener la placa.

Ecosistema Command: sigue `ESTANDAR.md` de `command-web`
(https://github.com/command-designs/command-web/blob/main/ESTANDAR.md) en lo que aplique a un proyecto
que no es web (§ 12 para dispositivos).

**Estado actual**: escritorio **labwc**. Desde el 2026-10-06 Command OS es un **paquete de pacman**
(`os/pkg`) con configuración de serie en el sistema, ganchos de pacman, bloqueo a prueba de
roturas, Arch de una fecha validada (x86), btrfs con instantáneas y pruebas automáticas en GitHub
Actions. **Cómo funciona y por qué: `docs/actualizaciones.md` (leerlo antes de tocar la
instalación).** Desde el 2026-10-07 no hay cuenta de serie: greetd con asistente de primer arranque,
pantalla de inicio de sesión propia e inicio automático opcional (`docs/cuentas.md`). La barra avisa
de actualizaciones (comprobación cada 6 h sin tocar el sistema, `docs/actualizaciones.md` § 7). Se ve
igual en 16:9 y 16:10 con escala automática de alta densidad y tema de GRUB propio
(`docs/notas/pantallas.md`). Al instalar en un PC, el disco se cifra (LUKS2, sí por defecto) con la
contraseña dentro del splash y clave de recuperación (`docs/cifrado.md`). En castellano de serie, con
el idioma (castellano o inglés) a elegir en el asistente y traducciones con gettext, escritorio incluido (`docs/idioma.md`). La zona horaria también se elige en el asistente, con hora por la red (`docs/cuentas.md` § «Hora»). La barra lleva la batería (avisos al 20 y al 10 %, límite de carga al 80 % si el portátil lo permite) y aplicaciones fijadas (`docs/notas/escritorio.md`). Desde el 2026-10-19 trae tienda de aplicaciones (Bazaar con Flathub, aparte de pacman), gestor de comprimidos en Thunar y tipos de archivo de serie para que nada descargado pregunte (`docs/notas/escritorio.md` § «Instalar aplicaciones»). Verificado en la VM x86_64 de VirtualBox. Falta: hardware real (lo prueba el
usuario); ARM, aparcado hasta tener la placa.

## Qué leer según la tarea (detalle en `docs/notas/`, léelo antes de tocar esa zona)

| Si vas a tocar… | Lee |
| --- | --- |
| paquete, ganchos de pacman, bloqueo, repositorio firmado, instantáneas, aviso y panel de actualizaciones | `docs/actualizaciones.md` y `docs/notas/estabilidad.md` |
| cuentas, contraseñas, primer arranque, inicio de sesión, greetd, zona horaria, reloj, NTP, panel de cuentas, `gestionar-cuentas` (pkexec) | `docs/cuentas.md` |
| idioma del sistema, `command-os-idioma`, textos traducibles, `os/po/`, `build/po.sh` | `docs/idioma.md` |
| escritorio labwc, Waybar, fondos, sonidos, menús, escritorios virtuales, batería y límite de carga (`gestionar-bateria`), aplicaciones fijadas | `docs/notas/escritorio.md` y `docs/DISENO.md` |
| colores, letra, forma (chaflanes, escuadras) o cualquier archivo de tema (marca v2 de command-web), notificaciones (swaync) | `docs/DISENO.md` § «Pantalla», `tests/marca.sh` y `docs/notas/escritorio.md` § «Marca v2, forma» |
| tienda (Bazaar, Flatpak), comprimidos (xarchiver), tipos de archivo (`mimeapps.list`), `command-os-abrir-descarga`, tema de las apps Flatpak | `docs/notas/escritorio.md` § «Instalar aplicaciones» |
| guía para quien instala (todas las formas) | `INSTALAR.md` (raíz): mantenerla al día con cualquier cambio del instalador |
| instalar en un PC (dual boot o disco entero), `build/x86/instalar.sh`, borrado de discos, instalador publicado y firmado | `docs/instalacion.md` (§ 2: instalador firmado; § 3: lo que protege del borrado) |
| cifrado del disco (LUKS), contraseña en el splash, clave de recuperación, panel del disco, `gestionar-disco`, `os/initcpio/`, `/boot` aparte | `docs/cifrado.md` |
| splash, firma de arranque, comprobaciones de arranque (`lib/diagnostico-arranque`), GRUB, arranque silencioso, imagen x86, USB, dual boot, bare metal | `docs/notas/arranque-e-imagenes.md` y `docs/dualboot.md` |
| resoluciones, 16:9/16:10, alta densidad (escala), fondos, tema de GRUB, tamaño del splash | `docs/notas/pantallas.md` |
| VM de VirtualBox, WSL2, capturas, pruebas a mano | `docs/notas/vm-virtualbox-wsl.md` y `docs/testing.md` |
| por qué se decidió algo (y qué se descartó) | `docs/decisiones.md` |
| qué viene ahora | `ROADMAP.md` (se quita cada punto al terminarlo y verificarlo) |

## Trampas que ya han roto algo (resumen; el porqué está en `docs/notas/`)

- XML de labwc: **ningún comentario puede contener `--`**: labwc deja de leer el archivo entero.
- Colores: solo los de la paleta v2 (`docs/DISENO.md`); `tests/marca.sh` falla con cualquier otro. Un
  color extra que haga falta se añade a su lista `EXTRA` con el motivo. Signal Red nunca para texto
  (no da contraste): texto, iconos y foco en Red Hot. Sin `text-shadow` ni halos (solo la barra del logo).
- Chaflanes en GTK: `border-image` con los SVG de `build/make-chaflanes.py` (regenerar al cambiarlos)
  **en archivo** (GTK 3 no carga `data:`) y el centro con un degradado (GTK no lo pinta). wofi: nunca
  `hide_search` (enseña una sola opción); el alto de un panel, con `--lines`.
- labwc suma las listas de escritorios al combinar configuraciones: la de serie no lleva `<names>`.
- Waybar: la configuración de serie va en `/usr/share/command-os/config/waybar/` y se pasa con
  `--config/--style` (`command-os-config`); `/etc/xdg/waybar/` ya existe por Arch. La hoja va además
  por `command-os-fijadas generar` (los iconos de las aplicaciones fijadas). `wlr/taskbar` no ejecuta
  órdenes al hacer clic: lo que tenga que lanzar algo va en un módulo `custom`. Los tests que importan
  `os/lib/*.py` van con `PYTHONDONTWRITEBYTECODE=1` (un `__pycache__` entraría en el paquete).
- hyprlock con errores de configuración no sale: pantalla en negro y sin campo. `command-os-lock` revisa antes.
- VirtualBox: **apagar la VM antes de que el PC entre en reposo** (se congela; recuperación en `docs/notas/vm-virtualbox-wsl.md`).
- Nunca matar QEMU con `Stop-Process -Force` / `kill -9` (corrompe archivos): `shutdown -h now` por SSH antes.
- Scripts `.sh` siempre con LF. `runuser` conserva el entorno de root (`as_user` fija HOME). En un chroot
  `systemd-detect-virt` ve el anfitrión (WSL): `is_vm` lo descarta.
- WSL cierra los procesos `setsid nohup` al terminar `wsl.exe`: para construir imágenes, `wsl.exe` en primer plano.
- Plymouth no se puede probar en WSL: probar en la VM. Al iterar con labwc, `kill -HUP $(pidof labwc)`;
  reiniciar hypridle por SSH lo deja escuchando la sesión SSH, no la de tty1.
- Prioridad x86: los cambios se hacen y se prueban en x86 (GRUB, `/etc/default/grub`). Que no rompan
  ARM (nada que dependa de x86 sin necesidad), pero sin trabajo ni pruebas propias de ARM/Pi hasta
  tener el hardware del cyberdeck. Lo ya escrito para el Pi (`cmdline.txt`) se deja como está.
- tty1 es de greetd: para una sesión nueva, `systemctl restart greetd` (no `getty@tty1`). Si la entrada
  falla, tty2 es la consola de emergencia. `deck`/`deck` es solo de desarrollo (`COMMAND_OS_DEV_USER`).
- Aviso de actualizaciones: nunca `pacman -Sy` para mirar (usa `checkupdates`, copia de la base de datos).
  La unidad tiene su propio `/tmp` y sistema de archivos de solo lectura: un repositorio de prueba
  `file://` va fuera de `/tmp`. Waybar oculta el módulo solo si el texto del JSON va vacío.
- Instalador en disco entero: **nunca ejecutarlo fuera de una VM o de discos loop** (borra el disco).
  Las comprobaciones de `disk_problems`/`confirm_erase` (`build/x86/lib.sh`) no se relajan sin una
  prueba nueva en `tests/discos.sh`. VM de pruebas: `command-os-instalador` (`docs/testing.md`).
  `grub-install` no actualiza una entrada UEFI con su misma ruta: `forget_nvram_entries` va antes.
  Sus mensajes van traducidos (`t`, `COMMAND_OS_IDIOMA`): nunca decidir buscando palabras en ellos
  (`disk_is_live_usb`, `disk_runs_system`), y las confirmaciones son las del idioma elegido, solo esas.
- Pantallas: hyprlock ignora la escala (la de serie se escala en `command-os-lock`) y GRUB no escala
  imágenes ni fuentes (tema generado por `apply-boot`). En VirtualBox, `setvideomodehint` no va (usar
  `wlr-randr` dentro) y 1366x768 sale roto en `screenshotpng` (capturar con `grim`).
- VirtualBox: **nunca `snapshot take --live`** con la VM encendida: la deja congelada (pasó con
  `command-os-x86`). Instantáneas con la VM apagada.
- Disco cifrado: `/boot` es otra partición y **el kernel no va en las instantáneas** (`command-os-rollback`
  lo repone). GRUB solo lee `/boot`: nada que GRUB necesite (fondo, tema, fuentes) puede ir en `/usr`.
  `cryptdevice=` va en `GRUB_CMDLINE_LINUX`, no en `_DEFAULT`. La contraseña de prueba en la VM, sin
  símbolos: `keyboardputstring` teclea como un teclado de EE. UU. y la VM usa el español.
- Initramfs: el busybox de mkinitcpio **no tiene `tr` ni `stty`**, y Plymouth pinta la ñ y las tildes
  como cuadrados (`label-freetype` sin locale): textos con acentos en el splash, como imágenes
  (una por idioma; el gancho sabe el idioma por `command-os.idioma=` en la línea del kernel).
  Datos para el tema del splash, con `plymouth update --status` (`display-message` sale en crudo en el
  modo detalles). `systemctl` con `-.mount`: siempre `--` antes (si no, lo toma por una opción).
- Textos: el original es el castellano dentro de `_()` (Python), `t`/`tn` (shell, de `lib/textos.sh`,
  el texto entero y literal), `{{…}}` (Waybar, hyprlock) o el `label="…"` del menú de labwc; un texto
  nuevo o cambiado necesita `bash build/po.sh` y su traducción en `os/po/`, o `tests/idioma.sh` falla.
  Nada de textos montados a trozos ni `t "$variable"`.
- El menú de labwc **no** va en `/etc/xdg/labwc` (con `--merge-config` gana el primero que se lee, el del
  sistema, y no se podría traducir): va en `/usr/share/command-os/config/labwc/` y `lib/menus-labwc`
  lo traduce al iniciar la sesión (`docs/idioma.md`). `printf '%-22s'` cuenta bytes: para alinear
  texto con flechas o «·», rellenar con `${#texto}`.
- cage se cierra cuando se cierra una tubería que hereda su programa: nada que se lance con `&` dentro
  de su `sh -c` puede quedársela (`pantallas.py vigilar` cierra los descriptores heredados) o la pantalla
  se queda en negro tras el asistente o el inicio de sesión.
- Nunca `rm -rf` de un chroot con montajes `--rbind` (/dev, /run…): entra en ellos y borra los del sistema.
- Apps Flatpak: dentro de su caja `/usr` es el del runtime. Lo que tengan que leer de `~/.config` (GTK)
  van copias, no enlaces a `/usr/share/command-os`. Un paquete nuevo puede venir roto en una fecha de
  Arch (Bazaar y libdex el 2026/10/05): `tests/escritorio.sh` mira que enlace (`LD_BIND_NOW`).
- Copiar a la VM: nunca `build/x86` entero (lleva los discos de las VM, ignorados por git, y llena
  `/tmp`): `git ls-files build | tar -czf - -T -`. `command-os-update` en la VM baja el paquete al
  publicado si el de desarrollo es más nuevo: reinstalar después con `install.sh`.
- Paneles del escritorio (`lib/panel-*.py`, `comun.ventana`/`Dialogo`): lo que necesita root va a
  `lib/gestionar-*` con `pkexec` (nunca `sudo -S` con una contraseña escrita en el panel); esos
  ayudantes contestan con códigos y reciben las contraseñas por la entrada estándar. Un texto de
  Python va con `_("…")` (no `self._("…")`: xgettext no lo ve) y cada archivo nuevo entra en `PYTHON` de
  `build/po.sh`. Probando en la VM por SSH: nunca `pkill -f <nombre>` desde la propia línea de SSH (se
  mata a sí misma), ni `sudo -S` con la entrada ocupada por una tubería (tres fallos: sudo bloqueado
  10 min), el ratón virtual se acelera (usar teclado: Tab/Intro) y `polkit` solo deja
  comprobar actualizaciones a la sesión local activa, no a un proceso lanzado por SSH.

## Qué se probó y qué se descartó (no repetir)

1. **VirtualBox con `vmsvga`/`vmwgfx` → descartado.** El compositor anterior no inicializaba sobre
   ese driver. Hoy la VM de VirtualBox usa `vboxsvga` con render por software y labwc va bien (ver
   "Identidad de marca y VM en VirtualBox").

2. **QEMU + `virtio-gpu-pci` sin aceleración 3D**: sirve para validar que el instalador corre bien
   (paquetes/servicios/dotfiles); para ver el escritorio, mejor la VM de VirtualBox.

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

## Siguientes pasos

En `ROADMAP.md`, por orden. Cada punto se quita al terminarlo y verificarlo.

## Cómo retomar la VM de desarrollo

Ver `docs/testing.md` para comandos exactos. Resumen:
- Forma preferida para el escritorio: VM de VirtualBox `command-os-x86` (SSH `127.0.0.1:2902` como
  `deck`), ya con labwc.
- Los discos QEMU (`/root/vm/command-os-dev.qcow2` en WSL, `build/packer/output-arch/` en Windows)
  son anteriores a labwc y llevan el escritorio viejo: **reconstruirlos** (Packer o
  `build/x86/build-image.sh`) en vez de re-correr `os/install.sh` encima, que ya no limpia el
  escritorio anterior.
- Llave SSH efímera en `build/packer/keys/packer_build_key` (gitignored,
  regenerar si no existe — ver `docs/testing.md`).
- Credenciales de desarrollo (no usar en producto final): usuario `deck` /
  password `deck` (solo imágenes con `DEV_SSH_PUBKEY`/`COMMAND_OS_DEV_USER`); `root` bloqueado.

## Convenciones del repo

- `os/` es el producto real (paquetes, install.sh, dotfiles) — arquitectura
  agnóstico, se usa igual en la VM x86_64 y (cuando haya hardware) en ARM.
- `build/packer/` es solo tooling de desarrollo para levantar la VM de
  pruebas rápido, no es parte del producto.
- Scripts `.sh` deben mantenerse con line endings LF (forzado por
  `.gitattributes`) — si un editor los toca y los pasa a CRLF, van a romper
  al ejecutarse dentro de la VM Linux.

## Compact instructions

Al compactar, conserva: la rama activa, las decisiones tomadas, el estado de las VM (`command-os-x86`,
`command-os-btrfs`) y los resultados de las pruebas.
