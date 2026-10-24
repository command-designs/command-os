# Trampas que ya han roto algo

Lista completa, por zona. `AGENTS.md` lleva el índice; léela antes de tocar la zona que toque. El porqué
de cada decisión está en `docs/decisiones/` y el detalle de cada zona, en `docs/notas/`.

## Peligros: pueden borrar o corromper algo

- Instalador en disco entero: **nunca ejecutarlo fuera de una VM o de discos loop** (borra el disco).
  Las comprobaciones de `disk_problems`/`confirm_erase` (`build/x86/lib.sh`) no se relajan sin una
  prueba nueva en `tests/discos.sh`. VM de pruebas: `command-os-instalador` (`docs/testing.md`).
  `grub-install` no actualiza una entrada UEFI con su misma ruta: `forget_nvram_entries` va antes.
  Sus mensajes van traducidos (`t`, `COMMAND_OS_IDIOMA`): nunca decidir buscando palabras en ellos
  (`disk_is_live_usb`, `disk_runs_system`), y las confirmaciones son las del idioma elegido, solo esas.
- Nunca `rm -rf` de un chroot con montajes `--rbind` (/dev, /run…): entra en ellos y borra los del sistema.
- Nunca matar QEMU con `Stop-Process -Force` / `kill -9` (corrompe archivos): `shutdown -h now` por SSH antes.
- VirtualBox: **apagar la VM antes de que el PC entre en reposo** (se congela; recuperación en `docs/notas/vm-virtualbox-wsl.md`).
- VirtualBox: **nunca `snapshot take --live`** con la VM encendida: la deja congelada (pasó con
  `command-os-x86`). Instantáneas con la VM apagada.
- Copiar a la VM: nunca `build/x86` entero (lleva los discos de las VM, ignorados por git, y llena
  `/tmp`): `git ls-files build | tar -czf - -T -`. `command-os-update` en la VM baja el paquete al
  publicado si el de desarrollo es más nuevo: reinstalar después con `install.sh`.

## Escritorio labwc, tema y barra

- XML de labwc: **ningún comentario puede contener `--`**: labwc deja de leer el archivo entero.
- Colores: solo los de la paleta v2 (`docs/DISENO.md`); `tests/marca.sh` falla con cualquier otro. Un
  color extra que haga falta se añade a su lista `EXTRA` con el motivo. Signal Red nunca para texto
  (no da contraste): texto, iconos y foco en Red Hot. Halos solo en la señal (barra del logo, trazo rojo
  del plano, cabezal de la firma y LED; BRAND 2.1): nunca `text-shadow` ni halos en paneles o bordes.
  También falla con los colores del estilo anterior aunque vayan sin `#` (swaylock) y con sus palabras
  en `os/` o `build/` (`PALABRAS`; las que hagan falta, en `PALABRAS_EXTRA` con el motivo).
- Chaflanes en GTK: `border-image` con los SVG de `build/make-chaflanes.py` (regenerar al cambiarlos)
  **en archivo** (GTK 3 no carga `data:`) y el centro con un degradado (GTK no lo pinta). wofi: nunca
  `hide_search` (enseña una sola opción); el alto de un panel, con `--lines`.
- Botones de ventana: un solo dibujo (`build/make-labwc-buttons.py`) para labwc y las cabeceras GTK
  (`botones/`); cambiar el alto en `themerc`, el generador y los dos `gtk.css` a la vez. Firefox
  descarta entera una política que no cuadra con su esquema: `tests/escritorio.sh` lo comprueba.
- labwc suma las listas de escritorios al combinar configuraciones: la de serie no lleva `<names>`.
- Waybar: la configuración de serie va en `/usr/share/command-os/config/waybar/` (`command-os-config`);
  `/etc/xdg/waybar/` ya existe por Arch. La lanza `command-os-fijadas waybar` con lo generado: la hoja con
  los iconos de las fijadas y `barra.jsonc` con el lado y si va flotante. En un `include` gana el archivo
  que incluye: lo generado incluye a la de serie, nunca al revés. `wlr/taskbar` no ejecuta
  órdenes al hacer clic: lo que tenga que lanzar algo va en un módulo `custom`. Un grupo no tiene clic
  propio: el mismo `on-click` en cada módulo. Sin adaptador, `bluetoothctl show` se queda esperando:
  mirar antes `/sys/class/bluetooth`. Los tests que importan
  `os/lib/*.py` van con `PYTHONDONTWRITEBYTECODE=1` (un `__pycache__` entraría en el paquete).
- El menú de labwc **no** va en `/etc/xdg/labwc` (con `--merge-config` gana el primero que se lee, el del
  sistema, y no se podría traducir): va en `/usr/share/command-os/config/labwc/` y `lib/menus-labwc`
  lo traduce al iniciar la sesión (`docs/idioma.md`). `printf '%-22s'` cuenta bytes: para alinear
  texto con flechas o «·», rellenar con `${#texto}` y `local LC_ALL=C.UTF-8` (sin un locale UTF-8, como en una
  sesión sin `LANG`, también cuenta bytes).

## Sesión Hyprland

- hyprlock con errores de configuración no sale: pantalla en negro y sin campo. `command-os-lock` revisa antes.
- Hyprland 0.56 (Lua): la API es la de `/usr/share/hypr/stubs/hl.meta.lua` instalada, no la de la wiki (va por
  delante: `window.minimize` no existe). `--verify-config` no mira dentro de las funciones (validar sus despachadores aparte)
  ni carga plugins (`tests/hyprbars.sh`). En `window.destroy` la ventana llega sin `address`: nunca indexar
  con él sin mirarlo (error de Lua en pantalla al cerrar cada ventana). El maximizado de Hyprland es uno por
  escritorio y se pierde al activar otra ventana: maximizar va por `colocar` (geometría y etiqueta
  `maximizada`), nunca por `fullscreen` con `maximized`. Con rofi abierto, soltar Alt no le llega
  siempre: lo mira Hyprland. `os/hyprbars` va atado a la versión exacta de Hyprland: otra fecha con otro Hyprland no se valida sin ponerlo al día.

## Entrada, actualizaciones y aplicaciones

- tty1 es de greetd: para una sesión nueva, `systemctl restart greetd` (no `getty@tty1`). Si la entrada
  falla, tty2 es la consola de emergencia. `deck`/`deck` es solo de desarrollo (`COMMAND_OS_DEV_USER`).
- Aviso de actualizaciones: nunca `pacman -Sy` para mirar (usa `checkupdates`, copia de la base de datos).
  La unidad tiene su propio `/tmp` y sistema de archivos de solo lectura: un repositorio de prueba
  `file://` va fuera de `/tmp`. Waybar oculta el módulo solo si el texto del JSON va vacío. Flatpak
  como root escribe en `/var/lib/flatpak` hasta para mirar (`remote-ls`): en la unidad, como `nobody`.
- cage se cierra cuando se cierra una tubería que hereda su programa: nada que se lance con `&` dentro
  de su `sh -c` puede quedársela (`pantallas.py vigilar` cierra los descriptores heredados) o la pantalla
  se queda en negro tras el asistente o el inicio de sesión.
- Apps Flatpak: dentro de su caja `/usr` es el del runtime. Lo que tengan que leer de `~/.config` (GTK)
  van copias, no enlaces a `/usr/share/command-os`. Un paquete nuevo puede venir roto en una fecha de
  Arch (Bazaar y libdex el 2026/10/05): `tests/escritorio.sh` mira que enlace (`LD_BIND_NOW`).

## Arranque, disco y pantallas

- Disco cifrado: `/boot` es otra partición y **el kernel no va en las instantáneas** (`command-os-rollback`
  lo repone). GRUB solo lee `/boot`: nada que GRUB necesite (fondo, tema, fuentes) puede ir en `/usr`.
  `cryptdevice=` va en `GRUB_CMDLINE_LINUX`, no en `_DEFAULT`. La contraseña de prueba en la VM, sin
  símbolos: `keyboardputstring` teclea como un teclado de EE. UU. y la VM usa el español.
- Initramfs: el busybox de mkinitcpio **no tiene `tr` ni `stty`**, y Plymouth pinta la ñ y las tildes
  como cuadrados (`label-freetype` sin locale): textos con acentos en el splash, como imágenes
  (una por idioma; el gancho sabe el idioma por `command-os.idioma=` en la línea del kernel).
  Datos para el tema del splash, con `plymouth update --status` (`display-message` sale en crudo en el
  modo detalles). `systemctl` con `-.mount`: siempre `--` antes (si no, lo toma por una opción).
- Pantallas: hyprlock ignora la escala (la de serie se escala en `command-os-lock`) y GRUB no escala
  imágenes ni fuentes (tema generado por `apply-boot`); busca cada fuente por el nombre entero del PF2
  (`cmd-menu Regular 14`) y, si no lo encuentra, usa otra sin avisar. En VirtualBox, `setvideomodehint` no va (usar
  `wlr-randr` dentro) y 1366x768 sale roto en `screenshotpng` (capturar con `grim`).
- Plymouth no se puede probar en WSL: probar en la VM. Al iterar con labwc, `kill -HUP $(pidof labwc)`;
  reiniciar hypridle por SSH lo deja escuchando la sesión SSH, no la de tty1.

## Textos e idioma

- Textos: el original es el castellano dentro de `_()` (Python), `t`/`tn` (shell, de `lib/textos.sh`,
  el texto entero y literal), `{{…}}` (Waybar, hyprlock) o el `label="…"` del menú de labwc; un texto
  nuevo o cambiado necesita `bash build/po.sh` y su traducción en `os/po/`, o `tests/idioma.sh` falla.
  Nada de textos montados a trozos ni `t "$variable"`.

## Ajustes y paneles

- Ajustes (`lib/ajustes.py`) y sus secciones (`lib/ajustes_*.py`, hijas de `comun.Seccion`: `limpiar`,
  `en_hilo`, `titulo`, `nota`, `avanzado` y `cada`, que solo corre con la sección a la vista); un panel
  suelto, `comun.PanelBase`; los formularios, `comun.Dialogo`. Una sección se importa al abrirla: nada
  pesado en el arranque de `ajustes.py`. Las reglas de contraseña y de usuario viven en
  `comun.py` y `reglas.sh`: no repetirlas. Lo que necesita root va a
  `lib/gestionar-*` con `pkexec` (nunca `sudo -S` con una contraseña escrita en el panel); esos
  ayudantes contestan con códigos y reciben las contraseñas por la entrada estándar. Un texto de
  Python va con `_("…")` (no `self._("…")`: xgettext no lo ve) y cada archivo nuevo entra en `PYTHON` de
  `build/po.sh`. Probando en la VM por SSH: nunca `pkill -f <nombre>` desde la propia línea de SSH (se
  mata a sí misma), ni `sudo -S` con la entrada ocupada por una tubería (tres fallos: sudo bloqueado
  10 min), el ratón virtual se acelera (usar teclado: Tab/Intro) y `polkit` solo deja
  comprobar actualizaciones a la sesión local activa, no a un proceso lanzado por SSH.

## Entorno de desarrollo (VM, WSL, scripts)

- Scripts `.sh` siempre con LF. `runuser` conserva el entorno de root (`as_user` fija HOME). En un chroot
  `systemd-detect-virt` ve el anfitrión (WSL): `is_vm` lo descarta.
- WSL cierra los procesos `setsid nohup` al terminar `wsl.exe`: para construir imágenes, `wsl.exe` en primer plano.
- Prioridad x86: los cambios se hacen y se prueban en x86 (GRUB, `/etc/default/grub`). Que no rompan
  ARM (nada que dependa de x86 sin necesidad), pero sin trabajo ni pruebas propias de ARM/Pi hasta
  tener el hardware del cyberdeck. Lo ya escrito para el Pi (`cmdline.txt`) se deja como está.
