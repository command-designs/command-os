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

**Ligereza: requisito de primer orden** (decisión del usuario, 2026-10-21). Command OS tiene que ser lo
más ligero posible, mucho más que Windows y macOS, en memoria en reposo, CPU en reposo, disco y tiempo
de arranque. Se aplica a cada cambio, también al diseño y al movimiento:
- Nada residente que no haga falta: mejor un temporizador, un socket o lanzarlo al usarlo que un demonio.
  Ajustes (`lib/ajustes*.py`) y los paneles se abren y se cierran; no se quedan en memoria.
- Nada que gaste CPU en reposo: animaciones solo al entrar, salir o pasar el ratón, nunca en bucle;
  módulos de la barra con intervalos largos o por señal, no por sondeo frecuente.
- Ante dos opciones, la más ligera, salvo que la otra sea necesaria; el coste extra se mide y se anota
  en `docs/decisiones/README.md`. Nada de Electron ni de apps web empaquetadas de serie.
- Un paquete, servicio o compositor nuevo (Hyprland incluido) entra solo si su coste en memoria y
  arranque se mide y es asumible frente a lo que aporta.

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
el idioma (castellano o inglés) a elegir en el asistente y traducciones con gettext, escritorio incluido (`docs/idioma.md`).
La zona horaria también se elige en el asistente, con hora por la red (`docs/cuentas.md` § «Hora»).
La barra lleva la batería (avisos al 20 y al 10 %, límite de carga al 80 % si el portátil lo permite)
y aplicaciones fijadas; también el Bluetooth, apagado de serie, con blueman (`docs/notas/escritorio.md`).
Desde el 2026-10-19 trae tienda de aplicaciones (Bazaar con Flathub, aparte de pacman), gestor de
comprimidos en Thunar y tipos de archivo de serie para que nada descargado pregunte
(`docs/notas/escritorio.md` § «Instalar aplicaciones»).
Verificado en la VM x86_64 de VirtualBox. Falta: hardware real (lo prueba el
usuario); ARM, aparcado hasta tener la placa.

## Qué leer según la tarea (detalle en `docs/notas/`, léelo antes de tocar esa zona)

| Si vas a tocar… | Lee |
| --- | --- |
| paquete, ganchos de pacman, bloqueo, repositorio firmado, instantáneas, aviso y panel de actualizaciones | `docs/actualizaciones.md` y `docs/notas/estabilidad.md` |
| cuentas, contraseñas, primer arranque, inicio de sesión, greetd, zona horaria, reloj, NTP, panel de cuentas, `gestionar-cuentas` (pkexec) | `docs/cuentas.md` |
| idioma del sistema, `command-os-idioma`, textos traducibles, `os/po/`, `build/po.sh` | `docs/idioma.md` |
| escritorio labwc, sesión Hyprland de prueba (`hypr/hyprland.lua`, `command-os-session [labwc\|hyprland]`, barras de título `os/hyprbars`, menús `lib/menu-hyprland.py`, Alt+Tab `rofi/alttab.rasi`), Waybar (grupo de estado, telemetría), centro de control (`lib/centro.py`, `command-os-centro`), wi-fi (`lib/red.py`, `lib/redes.py`), fondos, sonidos, menús, escritorios virtuales, batería y límite de carga (`gestionar-bateria`), aplicaciones fijadas, Bluetooth | `docs/notas/escritorio.md` (§§ «Barra», «Ajustes y centro de control» y «Sesión Hyprland de prueba») y `docs/DISENO.md` |
| colores, letra, forma (chaflanes, escuadras), movimiento (transiciones y curvas) o cualquier archivo de tema (marca v2 de command-web), notificaciones (swaync) | `docs/DISENO.md` §§ «Color», «Letra», «Forma» y «Movimiento», `tests/marca.sh` y `docs/notas/escritorio.md` § «Marca v2, forma» |
| barra de título y botones de ventana (labwc y cabeceras GTK), Firefox (políticas, `os/dotfiles/firefox/`) | `docs/notas/escritorio.md` § «Ventanas iguales» |
| tienda (Bazaar, Flatpak), comprimidos (xarchiver), tipos de archivo (`mimeapps.list`), `command-os-abrir-descarga`, tema de las apps Flatpak | `docs/notas/escritorio.md` § «Instalar aplicaciones» |
| guía para quien instala (todas las formas) | `INSTALAR.md` (raíz): mantenerla al día con cualquier cambio del instalador |
| instalar en un PC (dual boot o disco entero), `build/x86/instalar.sh`, borrado de discos, instalador publicado y firmado | `docs/instalacion.md` (§ 2: instalador firmado; § 3: lo que protege del borrado) |
| cifrado del disco (LUKS), contraseña en el splash, clave de recuperación, panel del disco, `gestionar-disco`, `os/initcpio/`, `/boot` aparte | `docs/cifrado.md` |
| splash, firma de arranque, comprobaciones de arranque (`lib/diagnostico-arranque`), GRUB, arranque silencioso, imagen x86, USB, dual boot, bare metal | `docs/notas/arranque-e-imagenes.md` y `docs/dualboot.md` |
| resoluciones, 16:9/16:10, alta densidad (escala), fondos, tema de GRUB, tamaño del splash | `docs/notas/pantallas.md` |
| VM de VirtualBox, WSL2, capturas, pruebas a mano, las pruebas de la CI en WSL (`build/wsl/pruebas.sh`) | `docs/notas/vm-virtualbox-wsl.md`, `docs/testing.md` y, para no repetir pruebas fallidas, `docs/notas/historial-vm.md` |
| por qué se decidió algo (y qué se descartó) | `docs/decisiones/README.md` |
| qué viene ahora | `ROADMAP.md` (se quita cada punto al terminarlo y verificarlo) |

## Trampas que ya han roto algo (lista completa en `docs/trampas.md`: léela antes de tocar la zona)

| Zona | Qué cubre |
| --- | --- |
| `docs/trampas.md` § «Peligros: pueden borrar o corromper algo» | Instalador, chroots, QEMU, VirtualBox y copias a la VM. |
| `docs/trampas.md` § «Escritorio labwc, tema y barra» | XML de labwc, colores de la marca, chaflanes, botones de ventana, Waybar, menú de labwc. |
| `docs/trampas.md` § «Sesión Hyprland» | hyprlock, API Lua de Hyprland 0.56, hyprbars. |
| `docs/trampas.md` § «Entrada, actualizaciones y aplicaciones» | greetd, aviso de actualizaciones, cage, apps Flatpak. |
| `docs/trampas.md` § «Arranque, disco y pantallas» | Disco cifrado, initramfs y Plymouth, GRUB y escala de pantalla. |
| `docs/trampas.md` § «Textos e idioma» | Traducciones con gettext. |
| `docs/trampas.md` § «Ajustes y paneles» | `lib/ajustes*.py`, `comun.py`, ayudantes con pkexec. |
| `docs/trampas.md` § «Entorno de desarrollo (VM, WSL, scripts)» | LF, runuser, WSL y prioridad x86. |

Las que más daño hacen, siempre presentes:
- **Instalador en disco entero: nunca fuera de una VM o de discos loop** (borra el disco).
- Nunca matar QEMU con `kill -9` / `Stop-Process -Force` (corrompe archivos): `shutdown -h now` por SSH.
- VirtualBox: apagar la VM antes de que el PC entre en reposo, y nunca `snapshot take --live`.
- Nunca `rm -rf` de un chroot con montajes `--rbind` (/dev, /run…): borra los del sistema.
- XML de labwc: ningún comentario puede contener `--` (labwc deja de leer el archivo entero).
- Colores solo de la paleta v2 (`tests/marca.sh` falla con cualquier otro).
- Un texto nuevo o cambiado necesita `bash build/po.sh` y su traducción, o `tests/idioma.sh` falla.

## Siguientes pasos

En `ROADMAP.md`, por orden. Cada punto se quita al terminarlo y verificarlo.

## Cómo retomar la VM de desarrollo

Ver `docs/testing.md` para comandos exactos. Resumen:
- Forma preferida para el escritorio: VM de VirtualBox `command-os-x86` (SSH `127.0.0.1:2902` como
  `deck`), ya con labwc.
- Los discos QEMU viejos llevan el escritorio anterior: reconstruirlos, no reinstalar encima. Esto y
  lo que se probó y se descartó (VirtualBox `vmsvga`, QEMU con 3D, tecleo de Packer):
  `docs/notas/historial-vm.md`.
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
