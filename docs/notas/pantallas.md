# Notas: pantallas 16:9 y 16:10, alta densidad, GRUB y splash (2026-10-07)

Qué hace cada pieza para que todo se vea igual de bien en 16:9 (1366x768, 1920x1080, 2560x1440) y
16:10 (1280x800, 1920x1200, 2560x1600), con o sin alta densidad. El porqué de cada decisión, en
`docs/decisiones.md`.

## Escala de alta densidad (`os/lib/pantallas.py`, `command-os-pantallas`)

- **Regla**: píxeles por pulgada (del tamaño físico que da el monitor) entre 120 en paneles internos
  (`eDP`, `LVDS`, `DSI`: se miran de cerca) o 110 en monitores, redondeado a 0,25, entre 1 y 3, y con
  tope para que el alto útil no baje de 720 px. Sin tamaño fiable (0 mm, < 10 cm o que no casa con la
  proporción) se queda en 1. Ejemplos en `tests/pantallas.sh`: 13" 2560x1600 → 2; 14" 1920x1200 →
  1,25; 15,6" 1920x1080 → 1,25; 27" 2560x1440 → 1; 27" 4K → 1,5; 11,6" 1366x768 → 1.
- **A mano**: un número o `auto` en `~/.config/command-os/escala` (la cuenta) o
  `/etc/command-os/escala` (todo el equipo, también inicio de sesión y asistente). Respeta el tope.
- **Dónde se aplica**: `aplicar` al empezar la sesión (`labwc/autostart`, antes de la barra y el
  fondo) y dentro de cage antes de abrir el inicio de sesión y el asistente. `vigilar` (cada 2 s,
  `wlr-randr --json`) pone la escala a las pantallas que se conectan y el fondo a las que se conectan
  o cambian de modo; la escala de las que ya estaban no se toca (un cambio con wdisplays se respeta).
  Termina al cerrarse el compositor.
- **hyprlock no aplica la escala** (mide todo en píxeles físicos: probado con `fractional_scaling` 0,
  1 y 2). `command-os-lock` le da la configuración de serie con las medidas multiplicadas, un bloque
  por pantalla (`command-os-pantallas hyprlock`, ~50 ms), antes de revisarla en busca de errores
  (se revisa la que se va a usar). La configuración propia de una cuenta
  (`~/.config/hypr/hyprlock.conf`) se usa tal cual.
- Depende de `wlr-randr` (en `packages.txt`).

## Fondos 16:9 y 16:10

`build/make-wallpaper.py [16x9|16x10]` genera cada fondo en 2560x1440 (`command-<n>.png`) y
2560x1600 (`command-<n>-16x10.png`), con la composición en proporción al alto (la retícula de 26 px y
la rejilla de 64 px, en píxeles fijos).
`command-os-wallpaper` da a cada pantalla el más cercano (ancho/alto < 1,70 → 16:10; también 4:3 y
5:4, que con el 16:10 no recortan el plano). `void` (bloqueo, GRUB, asistente) va solo en
16:9: es liso y se recorta sin perder nada.

## Splash (Plymouth)

Fotogramas a doble resolución (`build/make-plymouth.py`, wordmark de 1280 px). `command.script`
mide todo en proporción al alto de la pantalla (a 1080 px, igual que antes: wordmark de 640 px), con
`K` entre 0,7 y 2, y reduce los fotogramas una sola vez al cargarlos. La letra de la consola de
arranque escala igual.

## Menú de GRUB (tema propio)

- Piezas en `os/branding/grub/` (`build/make-grub-theme.py`): panel y selección en nueve piezas y el
  wordmark de 200 a 600 px cada 20 (**GRUB no escala las imágenes del tema**).
- `lib/apply-boot` genera `/boot/grub/themes/command/` para el alto de la pantalla del equipo (modo
  preferido de `/sys/class/drm`, la interna si la hay): fuentes JetBrains Mono con `grub-mkfont` (menú
  20 px, textos 15 px, consola 18 px a 1080 de alto), `theme.txt` con el bloque centrado y
  `GRUB_GFXMODE=<nativa>,auto`. Sin `grub-mkfont` o sin la fuente, se queda sin tema (fondo `void`).
- `COMMAND_OS_PANTALLA=ANCHOxALTO` fija la pantalla (pruebas en VM y en CI); `generica` no mira la
  de la máquina (la usa `build-image.sh`: la imagen va a cualquier equipo) y deja `auto` con medidas de
  1080 hasta la siguiente actualización de GRUB o de command-os en el equipo.
- `grub-mkconfig` va con el `LANG` de `/etc/locale.conf`: las entradas salen en el idioma del
  sistema. Hoy los equipos se instalan con `en_US` (`build/x86/lib.sh`), así que salen en inglés.

## Probar resoluciones en la VM de VirtualBox

- `VBoxManage controlvm … setvideomodehint` **no funciona** con `vboxvideo` en esta VM
  (`hgsmi_get_mode_hints failed: -5`). El modo se cambia dentro: `wlr-randr --output VGA-1
  --custom-mode 1920x1200` en labwc o en cage (el del inicio de sesión: como root con
  `XDG_RUNTIME_DIR=/run/user/<uid de greeter>`).
- **1366x768 (y 1360, 1368) se ve roto en la captura de VirtualBox**, pero el sistema dibuja bien
  (`grim` dentro de la VM sale perfecto): en esa resolución, capturar con `grim`.
- GRUB y el splash: `VBoxManage setextradata command-os-x86 VBoxInternal2/EfiGraphicsResolution
  2560x1600` con la VM apagada (quitarlo después, sin valor), `COMMAND_OS_PANTALLA=… apply-boot` y,
  solo para la prueba, en `/boot/grub/grub.cfg`: `video=…`, `timeout_style=menu` y un `timeout` largo.
- La VM no da tamaño físico: la escala automática es 1. Para ver la alta densidad, escala a mano.
- **Asistente de primer arranque y pantalla de inicio de sesión** (verificados en 1024x600, 1024x768,
  1280x720, 1366x768, 1920x1080, 1920x1200 y 2560x1600): el panel (`comun.panel`) va en un
  `ScrolledWindow`, así que en una pantalla baja (1024x600, la de muchas pantallas pequeñas) se
  desplaza en vez de dejar el botón fuera de la pantalla; si cabe, se ve igual y centrado. El logo lleva
  `set_can_shrink(False)`: sin eso se encoge a 0 px y el panel se comprime en vez de desplazarse. Las
  capturas de la prueba se hacen con `grim` dentro de la VM tras `wlr-randr --custom-mode` en el `cage`
  del asistente (`docs/testing.md` § «Asistente de primer arranque en la VM»).
- **No verificado**: la escala automática con un panel real de alta densidad.
