# Notas: escritorio labwc, rediseño, energía y sonido

Detalle movido de `CLAUDE.md` sin cambios (2026-10-06). Lenguaje visual: `docs/DISENO.md`.

## Escritorio labwc (2026-10-05)

- **Por qué**: producto para clientes que tiene que gustar a la mayoría y ser muy ligero. labwc es
  flotante (barra de título, botones, barra de tareas, Alt+Tab, clic derecho, Super abre el
  lanzador), sin animaciones de ventana, y es el compositor por defecto de Raspberry Pi OS en el Pi 5.
  Decisión del usuario frente a un tiling compositor y a un escritorio tipo GNOME/XFCE. Hasta el
  2026-10-20 no quería nada de Hyprland salvo hyprlock/hypridle; desde entonces, una sesión Hyprland
  a prueba solo por las animaciones de ventana (§ «Sesión Hyprland de prueba»).
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
  hay nada (el script devuelve texto vacío y Waybar quita el módulo), `UPD N` con la etiqueta en Smoke y el
  número y un LED en Warn si hay versión nueva de command-os. Lo refresca cada minuto y con la señal 8 (`pkill
  -RTMIN+8 waybar`). Cómo se comprueba, por qué así y cómo se prueba: `docs/actualizaciones.md` § 7.
- **fastfetch**: logo de la C generado por `build/make-fastfetch-logo.py` (medios bloques, colores
  `$1`/`$2`) y configuración en `os/branding/fastfetch/`, instalados en `/usr/share/command-os/` y
  `/etc/xdg/fastfetch/`. El logo también va como icono del sistema (`/usr/share/pixmaps/command-os.png`,
  `LOGO=` de `os-release`).
- **Piezas**: swaybg (fondo), Waybar con `ext/workspaces` (labwc implementa ext-workspace) y
  `wlr/taskbar`, hyprlock/hypridle (bloqueo e inactividad por protocolos estándar; pantalla con
  `wlopm`), polkit-gnome, wdisplays, xorg-xwayland (arranca bajo demanda). La red, sin nm-applet
  (§ «Barra»).
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
- **GTK**: las apps con cabecera propia (GTK 4) no reciben marco de labwc; `gtk-3.0/gtk.css` y
  `gtk-4.0/gtk.css` les dibujan el mismo filo (Red Hot si están activas), la misma sombra oscura y la
  misma barra de título (§ «Ventanas iguales»).
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
- **Límite de carga al 80 %** (Ajustes → batería, también con clic derecho en la batería;
  `os/lib/ajustes_bateria.py`): solo aparece si el controlador expone `charge_control_end_threshold`.
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

## Bluetooth (2026-10-20)

- **Barra**: el módulo `bluetooth` de Waybar, en texto como el resto (`bt off`, `bt on` o `bt N` con N
  dispositivos conectados; sus nombres, al pasar el ratón). Sin adaptador no sale (`format-no-controller`
  vacío). Apagado, en Smoke como `vol mute`. Clic: el centro de control (§ «Ajustes y centro de control»), y en él
  «bluetooth» abre `command-os-bluetooth panel` (blueman-manager de
  520×400 sin barra de título bajo la barra, regla en `labwc/rc.xml`; otro clic lo cierra); clic
  derecho: `command-os-bluetooth cambiar` (`bluetoothctl power on|off`; al encender quita antes el
  bloqueo de `rfkill`, que la sesión activa puede tocar sin root).
- **Apagado de serie**: `lib/apply-system` activa `bluetooth.service` y pone `AutoEnable=false` en
  `/etc/bluetooth/main.conf`, una sola vez (marca `/var/lib/command-os/bluetooth`). bluez no guarda el
  encendido entre arranques: cada arranque empieza apagado. blueman 2.4 no tiene ajuste propio de
  encendido (su `PowerManager` copia el estado del adaptador).
- **blueman-applet** (autostart): el agente para emparejar con PIN y los avisos de conexión. Sin icono en
  la bandeja: el dconf de serie desactiva sus plugins `StatusIcon` y `ShowConnected`
  (`org/blueman/general/plugin-list`). labwc no lanza `/etc/xdg/autostart`, por eso va en el autostart.
- **Probado**: `tests/barra.sh` (el clic derecho con `bluetoothctl` y `rfkill` de mentira) y
  `tests/escritorio.sh` (servicio, `AutoEnable`, dconf y programas; la barra arranca sin bus del sistema
  y Waybar solo lo apunta en el log). **No probado**: con un adaptador de verdad (la VM no tiene):
  emparejar, el PIN, el desplegable en pantalla y que el `identifier` de la regla case con la ventana
  (`docs/prueba-en-pc-real.md` § 5).

## Aplicaciones fijadas (2026-10-15)

- **Cómo va**: Waybar no sabe fijar (`wlr/taskbar` solo enseña ventanas y su clic derecho no lanza
  órdenes). `os/lib/fijadas.py` escribe en `$XDG_RUNTIME_DIR/command-os/barra/` `fijadas.jsonc`
  (`group/fijadas` con un `custom/fijada#fN` por aplicación; lo incluye `config.jsonc` con `include`) y
  `estilo.css` (importa la hoja de la barra y pone cada icono de fondo en `#custom-fijada.fN`). El
  autostart lanza Waybar con `command-os-fijadas waybar` (§ «Barra»); si falla, arranca con la hoja y
  la configuración de siempre, sin fijadas. Al cambiar la lista, se regenera y se recarga Waybar (SIGUSR2).
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
  de pacman: nunca tocan la base de datos de pacman ni la fecha validada. En las instalaciones nuevas es
  su propio subvolumen (`@flatpak`): no entran en las instantáneas ni vuelven atrás con el sistema. Polkit de Flatpak: las cuentas
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

## Ventanas iguales (2026-10-21)

Punto 2 de la tanda «Diseño 2.1» (`ROADMAP.md`): una sola barra de título para labwc, GTK 3,
GTK 4/libadwaita y Firefox. Por qué así y qué se descartó: `docs/decisiones.md`.

- **Barra de título**: 32 px (botones de 36×32 en `themerc` y `build/make-labwc-buttons.py`, que
  también comprueba con `--comprobar` en `tests/marca.sh`). Las cabeceras GTK la copian en `gtk.css`
  con los mismos SVG: el paquete los pone también en `/usr/share/command-os/botones` (enlace
  `botones/` junto a las hojas de serie) y `command-os-user-setup` los copia a `~/.config/gtk-*/botones/`
  como los chaflanes (las apps Flatpak los leen por el permiso global de `lib/apply-system`). En GTK 4
  los botones de ventana no llevan `.titlebutton`: su regla sube la especificidad con un `:not()` para
  no encogerse con la de los demás botones de la cabecera.
- **libadwaita**: el filo va con `outline` por dentro (con `box-shadow` por fuera solo asomaba en un
  lado) y se quita su `filter: opacity(.5)` de la cabecera sin foco (`headerbar` y `toolbarview >
  .top-bar`): la inactiva ya se distingue por Void y Smoke, como en labwc. Lo que la app mete en la
  cabecera (pestañas, buscador, botones con chaflán) se encoge a 24–28 px para caber.
- **Límites**: los diálogos GTK 3 con cabecera (abrir archivo) se quedan en 36 px: GTK 3 reserva sitio
  para un subtítulo (`has-subtitle`) y eso no se cambia desde CSS. Los rótulos de la barra lateral de
  Thunar («Lugares», «Dispositivos») siguen en Geist negrita: Thunar 4.20 los pinta como filas de un
  `GtkTreeView` y el CSS no llega a ellas sin poner en mono la barra entera. La raya bajo la cabecera
  de Bazaar la dibuja libadwaita (`toolbarview`), en Steel.
- **Firefox**: barra de título de labwc (`browser.tabs.inTitlebar = 0`) y políticas de serie en
  `/etc/firefox/policies/policies.json` (página nueva sin patrocinados, historias, tiempo ni widgets;
  sin el botón de VPN, `IPProtectionAvailable`; sin estudios ni recomendaciones; todo sin bloquear).
  Firefox **descarta entera una política que no cuadra con su esquema** y solo lo dice en
  `about:policies` (en la 158, `Widgets` pasó de sí/no a objeto y volvieron los patrocinados):
  `tests/escritorio.sh` las compara con el esquema de la versión instalada. Los colores y la forma, con
  `command.css` (`/usr/share/command-os/firefox/`), que registra la autoconfiguración de Firefox
  (`/usr/lib/firefox/defaults/pref/command-os.js` → `/usr/lib/firefox/command-os.cfg`) como hoja de
  usuario: solo variables del propio tema de Firefox y radios, más la línea Red Hot de la pestaña
  activa; también en sus páginas `about:` (fondo Void, botón principal en Signal Red, la sección
  elegida en Slate con texto Red Hot). Con GTK oscuro Firefox no usa los colores GTK (ni con
  `browser.theme.native-theme`): usa su propio tema oscuro, de ahí la hoja.
- **Probado en la VM** (capturas y medidas de píxeles): kitty (labwc) y Bazaar activo e inactivo con la
  misma barra (32 px, Graphite/Void, raya Steel, mismos botones), el filo de Bazaar en los cuatro lados,
  las preferencias de Bazaar (rótulos de grupo en mono Smoke), un diálogo GTK 3 con el principal
  desactivado, Firefox (barra de labwc, pestañas cuadradas, línea Red Hot, campo Void, sin VPN, página
  nueva limpia, ajustes) y el inicio de sesión (selector y contraseña, los dos de 36 px). **No
  probado**: una app GTK 4 con botones de texto en la cabecera y una app Flatpak GTK con los botones
  nuevos (el permiso de `botones/` llega al reinstalar).

## Barra (2026-10-21)

Punto 3 de la tanda «Diseño 2.1» (`ROADMAP.md`): la barra como la de la app HUD de `lenguaje.html`
(cómo se ve: `docs/DISENO.md` § «Escritorio»). Por qué así y qué se descartó: `docs/decisiones.md`.

- **Archivos**: `os/dotfiles/waybar/{config.jsonc,style.css}`; 36 px. Las reglas de labwc que cuelgan
  paneles junto a la barra (`MoveToEdge`) respetan su zona reservada: no dependen del alto ni del lado.
- **Grupo de estado** (`group/estado`: red, Bluetooth, volumen, batería). Waybar no da clic a un grupo:
  cada módulo lleva el mismo `on-click` (`command-os-centro`) y el hover del grupo (`#estado:hover`) llega
  a todos. Clic derecho: red → `command-os-centro redes`, Bluetooth → encender o apagar, volumen →
  mezclador, batería → su sección de Ajustes.
- **Telemetría** (`group/telemetria`: CPU, TMP, MEM, cada 10 s). Oculta de serie: es lo único de la
  barra que se despierta solo. El ajuste va en `~/.config/command-os/barra` (`telemetria=si|no`) y lo
  aplica `command-os-fijadas` al escribir la parte generada de la barra (`fijadas.jsonc`, con el grupo
  vacío si está oculta, y en `estilo.css` la celda sin filo); `command-os-fijadas telemetria
  si|no|cambiar` lo cambia y recarga Waybar. Se enseña u oculta en Ajustes → Barra.
- **Panel de estado y wi-fi**: ya no hay paneles wofi ni `clave-wifi.py`. `command-os-estado` y
  `command-os-wifi` quedan como envoltorios de `command-os-centro` y `command-os-centro redes`
  (atajos y configuraciones viejas siguen valiendo); todo está en § «Ajustes y centro de control».
- **Lado y flotante** (punto 6 de la tanda 2, 2026-10-21): en Ajustes → Barra, o con `command-os-fijadas
  lado arriba|abajo|izquierda|derecha` y `flotante si|no|cambiar` (en `~/.config/command-os/barra`;
  recarga Waybar con SIGUSR2, que la recoloca sin cerrar la sesión). El autostart ya no lanza Waybar a
  mano: `command-os-fijadas waybar` genera y hace `exec waybar` con `barra.jsonc`, que incluye la
  configuración de serie (o la del usuario) y `fijadas.jsonc` y fija encima `position`, el grosor
  (`height` 36, o `width` 36 y `height` 0 a un lado) y, flotante, 8 px de `margin-*` y `"name":
  "flotante"`. **En un `include` de Waybar gana el archivo que incluye** (y entre los incluidos, el
  primero): por eso la configuración generada incluye a la de serie y no al revés. Si no puede generar,
  arranca con las de serie (arriba, fija). A un lado, `VERTICAL` (`lib/fijadas.py`) cambia los formatos
  por lecturas de dos líneas (etiqueta encima del valor, tres caracteres como mucho, `justify` center),
  la hora en dos líneas y el aviso de actualizaciones por su campo `alt` (`command-os-updates status`);
  los grupos van con `"orientation": "inherit"`. El CSS va por la clase que Waybar pone a la ventana
  con el lado (`window#waybar.left`…) y por `.flotante`: filo hacia la pantalla, filos entre celdas
  encima de cada una, la línea Red Hot de lo activo por el borde de dentro (a un lado crece de arriba
  abajo) y el LED de la red encima de la lectura.
- **Centro de control según el lado**: `lib/centro.py` cambia de id según el lado (`dev.commandlab.Centro`
  arriba, `…CentroAbajo` abajo o a la derecha, `…CentroIzquierda` a la izquierda), y `rc.xml` tiene una
  regla para cada uno, junto al grupo de estado (al final de la barra). La clase `lado-*` de la ventana
  cambia el aire y el desliz de entrada (`command.css`). Colgado de abajo, si creciera se saldría por
  abajo (labwc lo coloca una vez, al abrirse, por su esquina de arriba): la lista de redes tiene alto
  fijo (`ListaRedes(fija=True)`) y cambiar de página abre otro panel (`App.reabrir`). El mezclador y
  blueman siguen arriba a la derecha (`docs/decisiones.md`).
- **Probado** (lado y flotante): `tests/barra.sh` y en la VM los cuatro lados y flotante (por orden y
  desde Ajustes con el teclado), la ventana activa a un lado, el centro en cada lado y el paso a redes
  con la barra abajo. Waybar, 68 MB de RSS en cualquier lado; nada residente nuevo. **No probado** (la VM
  no tiene wi-fi): la lista de redes de alto fijo con la barra abajo (`docs/prueba-en-pc-real.md` § 5.12).
- **Sin nm-applet**: fuera del autostart y de `packages.txt` (en los equipos ya instalados queda como
  dependencia huérfana, sin arrancar). La bandeja queda para apps de terceros.
- **Probado**: `tests/barra.sh` (telemetría) y en la VM: barra a 36 px (logo, iconos apagados, activa
  con filo Steel y línea Red Hot, un solo grupo, sin bandeja ni celda vacía) y hover del grupo entero
  (Slate medido). Memoria en reposo tras arrancar: 661 MB antes y 669 MB después (ruido entre
  arranques; nm-applet ocupaba 56 MB de RSS, casi todo bibliotecas GTK compartidas). **No probado**
  (la VM no tiene wi-fi ni Bluetooth): `docs/prueba-en-pc-real.md` §§ 5.9 y 5.11.

## Ajustes y centro de control (2026-10-21)

Punto 5 de la tanda 2 (`ROADMAP.md`). Cómo se ve: `docs/DISENO.md` § «Escritorio»; por qué así y qué se
descartó: `docs/decisiones.md`.

- **Ajustes** (`os/lib/ajustes.py`, `command-os-ajustes [sección]`): una ventana con una barra lateral y
  secciones hijas de `comun.Seccion` (`lib/ajustes_*.py`: red, bluetooth, barra, pantalla, sonido,
  fondo, batería, cuentas, disco, actualizaciones, idioma y hora, sistema). Los paneles viejos son
  secciones; `command-os-ajustes wifi` (alias) abre la de red. Cada sección se importa al abrirla y
  lo avanzado va en su apartado «avanzado». Lo que lee el sistema vive en módulos sin interfaz que
  comparten con el centro: `lib/red.py` (nmcli), `lib/redes.py` (`ListaRedes`: la lista de redes y la
  contraseña en dos pasos; `al_dia()` vuelve a mirar el wi-fi), `lib/bt.py` (bluetoothctl; emparejar
  se hace en blueman) y `lib/sonido.py` (`pactl` en texto, no JSON).
- **Centro de control** (`os/lib/centro.py`, `command-os-centro [redes]`): ventana GTK 4 sin decorar y
  transparente que pinta el panel con su chaflán. La coloca una regla de labwc
  (`dev.commandlab.Centro` en `rc.xml`: `MoveToEdge` arriba y a la derecha, `AlwaysOnTop`), no
  `gtk4-layer-shell`. Wi-Fi y Bluetooth (encender o apagar, y la flecha a las redes o a Ajustes),
  volumen, brillo, batería y el botón a Ajustes. Los datos llegan en un hilo después de enseñarse:
  abrir no espera a `nmcli` ni a `bluetoothctl`.
- **Se cierra** al perder el foco, con Escape o con otro clic en la barra (Waybar no quita el foco al
  clicar: probado). Para que el clic en el escritorio también le quite el foco, `rc.xml` lleva en el
  contexto `Root` un clic izquierdo con `Unfocus`. Una orden que llega justo tras el cierre (0,5 s) no
  lo reabre: era el clic de cerrarlo.
- **Lanzador**: `command-os-session` copia al entrar los `.desktop` técnicos (`lstopo`,
  `nm-connection-editor`, `wdisplays`, `btop`, los de blueman y pavucontrol, `avahi-discover`,
  `bssh`, `bvnc`; los que no estén instalados se saltan) con `NoDisplay=true` a
  `$XDG_RUNTIME_DIR/command-os/xdg/applications/`, que va la primera de `XDG_DATA_DIRS` (delante de la
  de Flatpak). Los originales no se tocan: son del sistema. El menú de labwc deja `ajustes` y
  `recargar escritorio`; lo demás está en Ajustes.
- **Medido en la VM** (software, `GSK_RENDERER=cairo`): ventana en 0,6–0,75 s, datos +0,1–0,2 s; 98 MB
  de RSS y 54 MB de PSS con cairo. Nada se queda residente al cerrar.
- **Probado**: `tests/ajustes.sh` (secciones, redes y bluetooth con `nmcli` y `bluetoothctl` de
  mentira), `tests/escritorio.sh` (copias del lanzador) y en la VM el centro con clics de ratón de
  verdad (se cierra con otro clic en la barra, con Escape y al pulsar el fondo). **No probado** (la VM
  no tiene wi-fi, Bluetooth, brillo ni batería): `docs/prueba-en-pc-real.md` § 5.11.

## Sesión Hyprland de prueba (2026-10-21, en curso)

Punto 7 de la tanda 3 (`ROADMAP.md`). Condición del usuario: **solo cambian las animaciones**; lo demás
se ve y se usa como en labwc. labwc sigue de serie. Estudio de paridad con lo que hay en la fecha
validada de Arch (2026/10/18):

- **Versiones**: Hyprland 0.56.2 (64 MB instalado, frente a labwc 0.9.7), Waybar 0.15.0, rofi 2.0.0
  (Wayland). **Hyprland 0.56 se configura en Lua** (`hyprland.lua`; la wiki de `wiki.hypr.land` es la de
  git y puede ir por delante: lo que se use se valida con `Hyprland --verify-config`, que no necesita
  pantalla). `hyprbars` tiene versión fijada para la 0.56.2 en `hyprland-plugins` (`hyprpm.toml`,
  commit `7644cecd`) y el paquete de Arch trae las cabeceras (`/usr/include/hyprland`, `hyprland.pc`):
  se compila sin el código de Hyprland.

| labwc | Hyprland 0.56 | Trabajo |
| --- | --- | --- |
| Ventanas flotantes, cascada | regla para todas: `float`; colocación centrada | configuración |
| Barra de título y botones SVG (32 px, 36×32, hover) | `hyprbars`: botones **redondos** con un glifo en «sans», sin color al pasar el ratón | compilarlo nosotros con un parche: botones cuadrados de 36×32, colores de la marca y hover |
| Menú de ventana (clic derecho en la barra de título) | no existe | el `client-menu` de `menu.xml` con wofi junto al puntero |
| Menú del escritorio (clic derecho en el fondo) | no existe | atajo de ratón que no se come el clic (`non_consuming`): si no hay ventana debajo, el `root-menu` con wofi |
| Alt+Tab con lista de icono y título | `cycle_next` sin lista | rofi en modo ventana (soltar Alt elige: `!Alt-Alt_L`); 1 MB, nada residente |
| Minimizar (botón, Super+Abajo, barra de tareas) | no minimiza | escritorio especial `special:minimizadas` y el evento `window.minimize` de Lua (lo que pide la barra de tareas) |
| Arrastrar al borde: maximiza o media pantalla, con aviso | `general.snap` solo pega al borde | al soltar el botón (atajo `non_consuming`), Lua mira si el puntero está en el borde y encaja; sin el aviso previo |
| Escritorios dinámicos (`command-os-desktops`, `<names>` + SIGHUP + wtype) | escritorios numerados por `hyprctl` | rama Hyprland en `command-os-desktops` |
| Waybar: `ext/workspaces`, `wlr/taskbar` | Hyprland implementa `ext-workspace` y `wlr-foreign-toplevel` | igual |
| Reglas del centro, mezclador, blueman, btop, PiP | `hl.window_rule` con `move`/`size`/`pin` | configuración |
| Atajos de `rc.xml`, teclas multimedia con la sesión bloqueada | `hl.bind` (`locked = true`) | configuración |
| Filo Red Hot, sin redondeo, sombra | `general.col`, `decoration` | configuración |
| Recargar (menú, SIGHUP) | `hyprctl reload` | rama en los scripts que recargan labwc |

- **Plugin**: se carga al empezar (`hyprctl plugin load` y `hyprctl reload`); la configuración de
  `hyprbars` va dentro de `if hl.plugin.hyprbars` para que, sin él, Hyprland arranque igual (sin barras
  de título, no roto).
- **Animaciones**: las curvas de la marca como `hl.curve` (bezier; `ease-snap` sube a 1,25, Hyprland lo
  admite) y las duraciones en décimas de segundo (`speed` 1,6 = 160 ms y 2,8 = 280 ms).
- **Sin probar**: nada de esto se ve en la VM (sin 3D). Lo prueba el usuario en su portátil, con la
  memoria y la CPU en reposo frente a labwc.

## Rediseño del escritorio (2026-10-05, rama `rediseno`)

Historia: entonces el escritorio llevaba el estilo anterior a la marca v2 (`docs/decisiones.md`).
Criterio del usuario: se queda lo que **sirve** y lo que **crea ambiente y queda bien**; fuera lo que
ni sirve ni aporta ambiente. Detalle visual en `docs/DISENO.md`. El usuario pidió que se le pregunte
antes de cada cambio y que se le notifique (PushNotification) cuando haga falta su decisión.
- **Fondos** (`build/make-wallpaper.py`, numpy y Pillow): con la marca v2, **no paisajes** (el usuario
  rechazó skyline y mapa). `reticula` (de serie) y `plano`, y `void` para el bloqueo, GRUB y el
  asistente, todos en PNG (sin grano pesan poco). Las llamadas de `plano`, con la JetBrains Mono Medium del
  sistema (`ttf-jetbrains-mono-nerd`, o la de Windows; solo para generar); sus medidas del símbolo se
  comprueban contra el PNG del logo al generar. Selector `os/bin/command-os-wallpaper` (elección en `~/.config/command-os/wallpaper`;
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
  y en las transiciones CSS de la barra, las apps GTK y las notificaciones (`docs/DISENO.md` § «Movimiento»).
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
