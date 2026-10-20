# Notas: escritorio labwc, rediseño, energía y sonido

Detalle movido de `CLAUDE.md` sin cambios (2026-10-06). Lenguaje visual: `docs/DISENO.md`.

## Escritorio labwc (2026-10-05)

- **Por qué**: producto para clientes que tiene que gustar a la mayoría y ser muy ligero. labwc es
  flotante (barra de título, botones, barra de tareas, Alt+Tab, clic derecho, Super abre el
  lanzador), sin animaciones de ventana, y es el compositor por defecto de Raspberry Pi OS en el Pi 5.
  Decisión del usuario frente a un tiling compositor y a un escritorio tipo GNOME/XFCE. El usuario
  no quiere nada de Hyprland en el repo salvo hyprlock/hypridle (le gustan).
- **Archivos**: `os/dotfiles/labwc/` (`rc.xml` atajos/reglas, `menu.xml` menús (en castellano; se instala en `/usr/share/command-os/config/labwc/` y `lib/menus-labwc` lo traduce al iniciar sesión, `docs/idioma.md`),
  `autostart`, `environment`), tema de ventanas `os/branding/labwc/Command/labwc/` (`themerc` +
  botones SVG de `build/make-labwc-buttons.py`) instalado en `/usr/share/themes/Command`. Portales en
  `os/dotfiles/xdg-desktop-portal/labwc-portals.conf` (gtk + wlr). Ayuda de atajos
  `os/bin/command-os-keys` (Super+F1): si se cambia un atajo en `rc.xml`, cambiarlo también ahí.
  `os/bin/command-os-about` (Super+F2, o «acerca de cmd-os» en el menú): mismo panel de wofi; lee el
  paquete de `/usr/share/command-os/version`, la fecha de Arch de `pacman/snapshot-date` y la GPU de
  `fastfetch -s gpu --format json` (fastfetch ya no admite opciones de módulo por línea de comandos).
  Las etiquetas son ASCII: `printf '%-9s'` cuenta bytes y desalinea las acentuadas.
- **Escritorios** (petición del usuario: que no se vean si no se crea uno extra): labwc no crea
  escritorios en caliente, así que `os/bin/command-os-desktops nuevo|quitar` reescribe `<names>` en
  `~/.config/labwc/rc.xml`, recarga con SIGHUP y, al crear, salta al nuevo pulsando Super+N con
  `wtype` (labwc no tiene IPC). Quitar solo quita el último; labwc pasa sus ventanas al primero.
  Waybar los enseña a la derecha y `style.css` oculta el botón cuando es `:only-child`. Re-ejecutar
  `install.sh` vuelve a dejar uno solo.
- **Aviso de actualizaciones** (`custom/updates` en Waybar, `os/bin/command-os-updates`): oculto si no
  hay nada (el script devuelve texto vacío y Waybar quita el módulo), `upd N` con la etiqueta en Smoke y el
  número en Warn si hay versión nueva de command-os. Lo refresca cada minuto y con la señal 8 (`pkill
  -RTMIN+8 waybar`). Cómo se comprueba, por qué así y cómo se prueba: `docs/actualizaciones.md` § 7.
- **fastfetch**: logo de la C generado por `build/make-fastfetch-logo.py` (medios bloques, colores
  `$1`/`$2`) y configuración en `os/branding/fastfetch/`, instalados en `/usr/share/command-os/` y
  `/etc/xdg/fastfetch/`. El logo también va como icono del sistema (`/usr/share/pixmaps/command-os.png`,
  `LOGO=` de `os-release`).
- **Piezas**: swaybg (fondo), Waybar con `ext/workspaces` (labwc implementa ext-workspace) y
  `wlr/taskbar`, hyprlock/hypridle (bloqueo e inactividad por protocolos estándar; pantalla con
  `wlopm`), polkit-gnome, nm-applet en la bandeja, wdisplays, xorg-xwayland (arranca bajo demanda).
- **Ajustes por máquina** (los genera `install.sh`, no van en los dotfiles): `environment.d/local.env`
  (teclado de `/etc/command-os/kb_layout`) y `themerc-override` (sin sombras en VM). En VirtualBox,
  `video=1280x720` en la línea del kernel: todo el arranque y el escritorio a esa resolución.
- **Marca v2, colores y letra** (2026-10-19, verificado en la VM con capturas): inicio de sesión,
  escritorio, barra, ventanas activa e inactiva, Thunar (GTK 3), pavucontrol (GTK 4), kitty con fastfetch,
  lanzador, menú de energía, notificación, bloqueo y splash. El menú de GRUB no se vio (el arranque lo
  oculta): solo las piezas generadas. Menús de labwc y Alt+Tab, sin captura.
- **Marca v2, forma** (2026-10-19; por qué así, `docs/decisiones.md`): chaflanes con `border-image`
  (`build/make-chaflanes.py`; regenerar y pasar `tests/marca.sh` al cambiar un color o un tamaño).
  Las hojas GTK de serie los buscan en `chaflanes/` junto a ellas (enlace a `../../chaflanes` en
  `/usr/share/command-os/config/gtk-*`; copias en `~/.config/gtk-*/chaflanes/`); wofi, swaync y el
  inicio de sesión, con ruta absoluta. Las notificaciones son de **swaync** (`os/dotfiles/swaync/`:
  sonido por urgencia en `scripts`, Super+N `swaync-client --close-all`; solo las ventanas flotantes,
  sin el centro de notificaciones). **Verificado en la VM** con capturas: lanzador, menú de energía
  (las tres opciones), inicio de sesión y asistente (panel, escuadras, botones), bloqueo (escuadras),
  ventanas de muestra GTK 3 y GTK 4 (botones sueltos, unidos, principal, inactivo, menú y popover) y a
  escala 2 (el filo se ve algo suave: el SVG se pinta a 1x y GTK lo amplía). **No verificado**: un
  popover con flecha en una app real y el tema dentro de una app Flatpak GTK 3.
- **GTK**: las apps con cabecera propia (GTK 4, Firefox) no reciben marco de labwc; `gtk-3.0/gtk.css`
  y `gtk-4.0/gtk.css` les dibujan el mismo filo (Red Hot si están activas) y la misma sombra oscura.
- **Verificado en VM VirtualBox** (capturas): escritorio, barra con tareas, ventanas activa/inactiva
  (borde `#D13449` medido; desde la marca v2 es Red Hot `#F5482C`), botones, menú de ventana, Alt+Tab, lanzador con Super, ayuda de atajos,
  mezclador desplegable, bloqueo y desbloqueo, bloqueo automático a los 5 min, notificaciones, crear,
  usar y quitar escritorios, fastfetch, re-ejecución de `install.sh` con la sesión abierta y
  reinicio completo (splash → escritorio). Uso de memoria del sistema: ~616 MB. **No verificado**:
  clic derecho en el escritorio (sin ratón virtual), apagado de pantalla a los 10 min, teclas
  multimedia, Pi 5 y bare metal.
- **VirtualBox y el reposo del PC**: si Windows suspende con la VM encendida, al volver la VM se
  congela (log: dos SUSPENDING/RESUMING seguidos; el disco tardó 5 s en suspender) y no responde ni
  a SSH ni al botón ACPI. Solo queda `controlvm poweroff`; ext4 recupera el diario solo y la ESP
  (FAT) queda marcada sucia: `umount /boot && fsck.fat -a /dev/sda1 && mount /boot`. Apagar la VM
  antes de dejar el PC en reposo.
- Cómo probar sin ratón (wtype, SIGHUP, bloqueo de la sesión de tty1, capturas): `docs/testing.md`,
  sección "labwc en la VM".


## Batería (2026-10-15)

- **Barra**: el módulo `battery` de Waybar, en texto (`bat 85%`, el tiempo que queda descargándose y
  `+` cargando; el usuario lo quiere así, sin icono). Clic derecho: el panel de la batería.
- **Avisos** (`command-os-bateria watch`, autostart; `os/lib/bateria.py`): al 20 % normal y al 10 %
  urgente (swaync lo deja hasta cerrarlo, con su sonido), una vez por descarga; al enchufar, un aviso
  breve los sustituye. Mira `/sys/class/power_supply` cada minuto: fuera las baterías de periféricos
  (`scope` = Device); varias baterías cuentan juntas si todas dan energía (o todas carga).
- **Límite de carga al 80 %** (panel: clic derecho en la batería o menú → ajustes → batería;
  `os/lib/panel-bateria.py`): solo aparece si el controlador expone `charge_control_end_threshold`.
  Lo pone `lib/gestionar-bateria` con pkexec (sesión activa sin contraseña); guarda
  `/etc/command-os/limite-carga` y lo vuelven a poner udev al aparecer la batería (también al
  arrancar) y `/usr/lib/systemd/system-sleep/command-os-bateria` al despertar. Inicio a 75 si hay
  `charge_control_start_threshold`; en los Dell, modo `Custom` (el de antes se apunta en
  `limite-carga.modos` y vuelve al quitarlo). Si el firmware rechaza un orden de escritura (inicio por
  encima del fin) prueba el otro; si rechaza el valor, todo queda como estaba. Apagado de serie. Por
  qué así: `docs/decisiones.md`.
- **Probado**: `tests/barra.sh` (batería simulada con `COMMAND_OS_POWER_SUPPLY`, avisos, límite sobre
  un sysfs de mentira) y en la VM con una batería simulada (panel, avisos de mako, polkit sin
  contraseña en la sesión activa). **No probado**: un portátil real (la VM no tiene batería): el límite
  en el firmware y que siga tras reiniciar y tras el reposo.

## Aplicaciones fijadas (2026-10-15)

- **Cómo va**: Waybar no sabe fijar (`wlr/taskbar` solo enseña ventanas y su clic derecho no lanza
  órdenes). `os/lib/fijadas.py` escribe en `$XDG_RUNTIME_DIR/command-os/barra/` `fijadas.jsonc`
  (`group/fijadas` con un `custom/fijada#fN` por aplicación; lo incluye `config.jsonc` con `include`) y
  `estilo.css` (importa la hoja de la barra y pone cada icono de fondo en `#custom-fijada.fN`). El
  autostart lanza Waybar con `command-os-fijadas generar <hoja>`; si falla, devuelve la hoja de
  siempre y la barra arranca sin fijadas. Al cambiar la lista, se regenera y se recarga Waybar (SIGUSR2).
- **Lista**: `~/.config/command-os/fijadas`, un `.desktop` por línea; sin el archivo, las de serie
  (Firefox, Thunar, kitty). Las desinstaladas desaparecen solas. Iconos de Papirus-Dark (SVG primero),
  sus padres o `/usr/share/pixmaps`, sin GTK.
- **Uso**: clic abre (`gio launch`); clic derecho en una fijada: quitar, mover a la izquierda o a la
  derecha, fijar otra; clic derecho en el logo: el lanzador, que fija en vez de abrir
  (`drun-print_desktop_file`). Una fijada abierta sale también como ventana en la barra de tareas.
- **Probado**: `tests/barra.sh` y en la VM (iconos de serie, menú, mover, fijar btop desde el lanzador,
  abrir kitty). `tests/escritorio.sh` comprueba que la barra arranca con las fijadas.


## Instalar aplicaciones (2026-10-19)

Petición del usuario: que instalar algo nunca sea un problema (en su portátil, un Discord descargado
en `.tar.gz` le preguntó con qué abrirse). Por qué así y qué se descartó: `docs/decisiones.md`.

- **Tienda**: Bazaar (paquete `bazaar`), solo Flatpak, con Flathub (el paquete `flatpak` trae el remoto
  en `/usr/share/flatpak/remotes.d`). Las apps van en `/var/lib/flatpak` (instalación del sistema), aparte
  de pacman: nunca tocan la base de datos de pacman ni la fecha validada. Polkit de Flatpak: las cuentas
  de `wheel` instalan sin contraseña en la sesión activa; las demás piden la de un administrador. Se
  abre con `command-os-tienda` (menú → tienda de aplicaciones, fijada de serie en la barra) y
  `command-os-tienda buscar TEXTO` la abre buscando. Bazaar avisa de los permisos de cada app (Discord:
  «alto riesgo», X11 y propietaria). `libheif` hace falta para las capturas de Flathub (AVIF).
- **Actualizar**: `command-os-update` (`update`) actualiza las apps al final, contra Flathub del día y
  sin preguntar (las del sistema y las que quien lo lanza instaló solo para su cuenta, `--user`), y quita
  los runtimes que ya no usa nadie; si falla (sin red), lo de pacman queda hecho.
  El aviso de la barra y su panel cuentan las apps del sistema con versión nueva (no las `--user`:
  `docs/actualizaciones.md` § 7). Bazaar también las actualiza.
- **Lanzador y fijadas**: `command-os-session` carga `/etc/profile.d/flatpak.sh` (greetd no abre un shell
  de entrada), así que `XDG_DATA_DIRS` lleva las carpetas `exports/share` de Flatpak: wofi y las fijadas
  ven sus `.desktop` e iconos.
- **Tema**: un permiso global (`flatpak override --system`, `lib/apply-system`) deja a las apps leer, en
  solo lectura, `gtk.css` y `settings.ini` de `~/.config/gtk-3.0` y `gtk-4.0` (solo esos archivos: la
  carpeta guarda también los marcadores). Dentro de su caja `/usr` es el del runtime, así que
  **esos archivos son copias, no enlaces** (`command-os-user-setup`; la suma de la última copia queda en
  `~/.config/command-os/gtk/` y se pone al día si el usuario no la ha tocado). El modo oscuro y el tema
  llegan de dconf por el portal; Flatpak descarga solo la extensión `org.gtk.Gtk3theme.adw-gtk3-dark` al
  instalar la primera app. Papirus y las fuentes se ven desde la caja (`/run/host`).
- **Comprimidos**: xarchiver (GTK 3, el mismo tema que Thunar) con `thunar-archive-plugin` (clic derecho:
  extraer aquí, extraer en…, crear comprimido), `7zip` y `unrar`.
- **Tipos de archivo**: `/usr/share/applications/mimeapps.list` (`os/dotfiles/applications/`), las
  aplicaciones de serie de la distribución; lo que elija el usuario va a `~/.config/mimeapps.list` y gana.
  Comprimidos → xarchiver; `.flatpakref`, `.flatpak` y `appstream://` → Bazaar; AppImage, `.deb`, `.rpm`
  y `.flatpakrepo` → `command-os-abrir-descarga` (`lib/abrir-descarga.py`, lógica en `lib/descargas.py`).
- **`command-os-abrir-descarga`** (ventana como los paneles; app_id `dev.commandlab.AbrirDescarga`, igual
  que su `.desktop`, para que la barra de tareas tenga icono): un AppImage avisa de que es un programa
  descargado; al aceptar comprueba que sea para este procesador (cabecera ELF), lo marca como ejecutable
  y lo abre (`fuse2`); si se cierra con error en 3 s, lo dice. Un `.deb` o `.rpm` explica que es de otra
  distribución y busca la app en la tienda por su nombre sin versión ni arquitectura. Un
  `.flatpakrepo` añade el repositorio si se confirma.
- **Probado**: `tests/aplicaciones.sh` (descargas, asociaciones, `command-os-tienda`, copias del tema) y
  `tests/escritorio.sh` (cada tipo abre con su aplicación según GIO, Bazaar y xarchiver enlazan con las
  bibliotecas de la fecha, Flathub, el permiso del tema y `XDG_DATA_DIRS` de la sesión). En la VM, con la
  fecha 2026/10/18: buscar «discord» en la tienda, instalar Discord (sin contraseña) y abrirlo desde wofi;
  fijarlo (icono de Papirus); el tema GTK dentro de su caja; «extraer aquí» de un `.tar.gz` en Thunar y
  abrirlo en xarchiver con su aplicación por defecto; la ventana de un `.deb` (→ tienda buscando
  «discord») y de un AppImage (que falla al abrirse y para ARM). **No probado**: el doble clic con un
  ratón de verdad en Thunar (en la VM, el toque virtual no da el foco a Thunar: se probó la misma acción,
  abrir con la aplicación por defecto), un AppImage real y una app GTK 3 de Flathub (Discord es Electron).
- **Al probar en la VM**: `polkit` solo deja instalar a la sesión local, no a SSH: la tienda se abre
  desde una terminal de la sesión (`sh t.sh`). Los botones de GTK se pulsan bien con una pantalla
  táctil virtual de uinput (`ABS_X/ABS_Y` + `BTN_TOUCH`, `INPUT_PROP_DIRECT`: coordenadas exactas, sin la
  aceleración del ratón virtual; `docs/testing.md`).


## Rediseño del escritorio (2026-10-05, rama `rediseno`)

Historia: entonces el escritorio llevaba el estilo anterior a la marca v2 (`docs/decisiones.md`).
Criterio del usuario: se queda lo que **sirve** y lo que **crea ambiente y queda bien**; fuera lo que
ni sirve ni aporta ambiente. Detalle visual en `docs/DISENO.md`. El usuario pidió que se le pregunte
antes de cada cambio y que se le notifique (PushNotification) cuando haga falta su decisión.
- **Fondos** (`build/make-wallpaper.py`, numpy y Pillow): con la marca v2, **no paisajes** (el usuario
  rechazó skyline y mapa). `reticula` (de serie) y `plano`, y `void` para el bloqueo, GRUB y el
  asistente, todos en PNG (sin grano pesan poco). Las cotas de `plano`, con JetBrains Mono de
  `build/fonts/` (OFL, solo para generar); sus medidas del símbolo se comprueban contra el PNG del
  logo al generar. Selector `os/bin/command-os-wallpaper` (elección en `~/.config/command-os/wallpaper`;
  un nombre que ya no está en la lista, como los de antes de la v2, vuelve al de serie), lo llama
  `autostart` y el menú ajustes → fondo de pantalla. `.gitattributes`: `*.png binary` en
  `os/branding/` (si no, la regla de texto los corrompería). Para generarlos en Windows, numpy y
  Pillow en un entorno virtual fuera del repo (el `python3` de Windows es el de la Store).
- **Barra**: reloj con fecha (Waybar pasa **un** argumento de fecha: con dos `{:...}` el módulo no
  arranca; usar `{0:%d.%m}  {0:%H:%M}`), temperatura (en la VM no hay `thermal_zone0` y el módulo
  se desactiva solo, es normal), batería con tiempo restante (avisos y límite de carga: § «Batería»),
  señal wifi, umbrales Warn/Red Hot.
- **Ventanas**: barra de título plana, títulos y Alt+Tab en JetBrains Mono, sombra oscura de 12 px (sin halo rojo desde la marca v2).
- **Bloqueo**: `immediate_render` (sin él, hyprlock espera hasta 2 s a sus recursos antes de
  bloquear) y el sonido de bloqueo en segundo plano en `hypridle.conf` (antes bloqueaba al terminar
  el sonido). Medido: Super+L → sesión bloqueada en ~350 ms. Línea de estado real
  (`os/bin/command-os-status`), intentos fallidos y aviso de mayúsculas en Warn.
- **Sonidos** (`build/make-sounds.py`, numpy): de aparato real (clics, pitidos, barridos, golpe de
  encendido), sala seca. `login.wav` eliminado (no se usaba). **No se han escuchado**: verificado
  solo que no saturan; que el usuario los oiga. Sustituidos el 2026-10-19 por los de la marca v2
  (`docs/DISENO.md` § «Sonido»).
- **Paquetes**: fuera las herramientas personales de desarrollo (alacritty, vim, tmux, htop, ripgrep,
  fd, fzf, bat, eza, zoxide, jq, tree, rsync, wget, nodejs, npm…) y sus alias del `bashrc`. python
  ya no está en la lista pero sigue instalado porque kitty depende de él. Se quedan base-devel + git
  (AUR). En máquinas ya instaladas `install.sh` no desinstala nada: en la VM se quitó a mano.
- **SSH**: apagado en el producto; `install.sh` lo enciende solo con la variante `vbox` o
  `COMMAND_OS_SSH=1` (lo pasan `build-image.sh` si hay `DEV_SSH_PUBKEY` y el script de Packer).
- Al probar: reiniciar hypridle por SSH lo deja escuchando la sesión SSH, no la de tty1 (Super+L deja
  de bloquear). Para aplicar cambios de la sesión, `sudo systemctl restart greetd` (tty1 es de greetd desde el 2026-10-07) y comprobar
  que no queden dos hypridle.


## Menú de energía y mezclador (2026-10-04)

- `os/bin/command-os-power`: Super+Escape o botón 󰐥 de la barra → bloquear / reiniciar / apagar (con
  confirmación), por logind sin contraseña. Verificado en VM: apagado limpio en ~6 s.
- `os/bin/command-os-volume`: clic en `vol` → pavucontrol 460×340 sin barra de título bajo la barra
  (regla en `labwc/rc.xml`); otro clic lo cierra.
- VirtualBox: la X de la ventana pregunta; "Enviar la señal de apagado" es limpio, "Apagar la
  máquina" es desenchufar.


## Consola de desarrollo, animaciones y sonido (2026-10-01)

- **Paquetes de desarrollo** en `os/packages.txt` (nano, base-devel, man, ripgrep, fd, fzf, bat, eza,
  zoxide, tmux, jq, python, nodejs/npm…) y pila de audio PipeWire completa. `install.sh` instala
  `~/.config/command-os/bashrc` (alias, prompt de marca, `EDITOR=nano`) enganchado desde `~/.bashrc`
  con marcadores, y `~/.config/nano/nanorc`.
- **Animaciones**: con labwc no hay animaciones de ventana; el movimiento está en los paneles
  (entrada de Wofi con `@keyframes`) y en las transiciones CSS de Waybar (ver `docs/DISENO.md`).
- **Sonidos**: `build/make-sounds.py` los genera en `os/branding/sounds/`; `os/bin/command-os-sound`
  los reproduce (arranque, notificación, urgente, bloqueo, desbloqueo, tecla de volumen).
- **VirtualBox**: 4 vCPU solo con CPU hotplug (sin hotplug, 2 vCPU = cuelgue en `DXE_AP`), 6 GB de
  RAM, paravirt KVM, y **audio AC97** (con HDA `pw-play` se cuelga). El escritorio renderiza por software
  en la VM, así que la fluidez real de las animaciones solo se juzga en bare metal / Pi. Detalle en
  `docs/testing.md`.
- Al iterar con labwc, re-ejecutar `install.sh` con la sesión abierta funciona; para ver los cambios,
  `kill -HUP $(pidof labwc)` (o `sudo systemctl restart greetd` para una sesión nueva).
- Pendiente: oír los sonidos en la VM (solo se verificó que `pw-play` termina a tiempo, no el
  resultado acústico), validar los paquetes en aarch64 y probar el audio en el Pi.
