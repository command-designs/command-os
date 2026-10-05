# Command OS — Lenguaje del producto

Cómo se ve y se mueve Command OS (`CMD-OS`). Es el sistema de un dispositivo, así que su interfaz es
propia; lo une a Command el cumplimiento de las anclas de `BRAND.md` § 12 (tabla al final).
Fuente de la marca: <https://github.com/command-designs/command-web> (`BRAND.md`, `tokens.css`).

## Idea

Un HUD de Night City sobre un terminal de Command: la estructura, la densidad y el tono de
Cyberpunk 2077 (paneles con filos, esquinas vivas, rótulos pequeños, brillo contenido, glitch), con el
ADN de Command (Red Hot como primario, wordmark con su barra, matriz de puntos, voz en minúsculas,
curva de movimiento sin rebotes). El rojo manda; el cian acompaña; el resto se queda en la sombra.

## Pantalla

- **Paleta HUD**, en los tonos apagados de los menús de Cyberpunk 2077 (no neón chillón). Escrita a
  mano en cada dotfile: tema de ventanas de labwc (`themerc`), Waybar, Wofi, Mako, Hyprlock, Kitty,
  Alacritty, GTK 3/4, prompt de bash, Plymouth y los scripts de `build/` (botones de la barra de
  título incluidos); si cambia, hay que actualizarlos todos:

  | Token      | Hex                              | Uso                                                                 |
  | ---------- | -------------------------------- | ------------------------------------------------------------------- |
  | Void       | `#0D0B0E`                        | fondo (negro con un punto cálido); fondo de listas en las apps      |
  | Graphite   | `#15121A`                        | superficies (paneles, campos, notificaciones, ventanas de apps)     |
  | Slate      | `#1D1820`                        | superficies elevadas (menús, popovers, diálogos)                    |
  | Steel      | `#2E2630`                        | bordes y separadores inactivos                                      |
  | Bone       | `#EDEBE6`                        | texto (de Command)                                                  |
  | Ash        | `#A8A2A6` · Smoke `#6F6870`      | texto secundario / apagado                                          |
  | Red        | `#D13449`                        | **primario**: activo, foco, marco de ventana, cursor, acento de apps (rojo de los menús de 2077) |
  | Red Light  | `#E8607A`                        | texto o iconos en rojo sobre fondo oscuro (acento suelto en GTK)    |
  | Red Deep   | `#2B1118`                        | fondo de lo seleccionado (en GTK, el rojo al 32 %)                  |
  | Signal Red | `#A51500`                        | barra del logo, sin cambios                                         |
  | Cyan       | `#5BBFC4` · Cyan Dim `#2F6E72`   | **secundario**: datos, etiquetas, rutas, enlaces, info              |
  | Yellow     | `#E2C044`                        | solo avisos (batería baja, error del último comando, urgente)       |

- **Tipografía:** JetBrains Mono en barra y terminal; Geist en lanzador y notificaciones; Oxanium en
  el reloj de la barra, la hora del bloqueo y los rótulos del fondo. Oxanium y Geist no están en los
  repos de Arch y se instalan desde `os/branding/fonts/` (licencia OFL incluida).
- **Forma:** esquinas vivas (radio 0), bordes de 1–2 px. Lo seleccionado se marca con un filo rojo
  a la izquierda sobre Red Deep y un brillo en el texto.
- **Ventanas (labwc, tema `Command` en `os/branding/labwc/`):** flotantes, con barra de título y
  botones a la derecha (minimizar · maximizar · cerrar) como en cualquier escritorio. La activa: filo
  rojo de 1 px, barra en degradado Slate → Graphite con el título en Geist negrita y un halo rojo
  suave (sombra sin desplazamiento). La inactiva: filo Steel, barra Void, título y botones en Smoke y
  una sombra oscura corta que la separa del fondo. Botones dibujados a propósito
  (`build/make-labwc-buttons.py`): maximizar son las escuadras del fondo; al pasar por encima, cian
  sobre Slate, y cerrar en rojo sobre Red Deep. Las apps que se dibujan su propia cabecera (GTK 4,
  Firefox) llevan el mismo filo y halo desde `gtk.css`. Arrastrar al borde encaja la ventana (arriba
  maximiza; lados, media pantalla) con una guía roja translúcida.
- **Apps (GTK 3/4 y Qt):** mismo tema que el escritorio, sin ventanas blancas. Base `adw-gtk3-dark`
  recoloreada en `~/.config/gtk-3.0/gtk.css` y `gtk-4.0/gtk.css` (colores con nombre y variables
  de libadwaita): ventana en Graphite, listas en Void, cabeceras en Void con filo rojo, menús en
  Slate con filo rojo, selección en rojo al 32 % con filo rojo a la izquierda, esquinas vivas. Qt
  sigue a GTK (`QT_QPA_PLATFORMTHEME=gtk3`). Iconos Papirus-Dark con carpetas grises
  (`command-os-icon-folders`; el rojo queda para lo activo). `dconf` pone el modo oscuro para todo el
  sistema (Firefox y portales incluidos).
- **Barra (Waybar):** a la izquierda, logo (clic: aplicaciones) y barra de tareas con un icono por
  ventana (la enfocada con filo rojo, las minimizadas atenuadas); en el centro, el reloj en Oxanium
  entre filos rojos; a la derecha, los escritorios, los datos con su etiqueta en cian, la bandeja (red
  de nm-applet) y el botón de energía.
- **Escritorios:** uno de serie, y la barra no enseña nada. Super+Ctrl+D (o clic derecho →
  `escritorios`) crea otro, hasta 4, y salta a él; entonces aparecen sus números (`01 02…`) a la
  derecha de la barra, el activo en rojo. Super+Ctrl+F4 quita el último y sus ventanas pasan al 01
  (`command-os-desktops`).
- **fastfetch:** la C de Command con su barra en Signal Red (`build/make-fastfetch-logo.py`), claves
  en castellano y minúsculas en cian, separador `›` rojo, valores en hueso y porcentajes en cian,
  ámbar o rojo según el nivel. Configuración de sistema en `/etc/xdg/fastfetch/`.
- **Menús de labwc** (clic derecho en el escritorio o en la barra de título): Slate con filo rojo,
  opción activa en Red Deep con el texto en Red Light, rótulos de sección en cian sobre Void y textos
  en la voz de la marca (`aplicaciones`, `ajustes`, `mover a`…). **Alt+Tab** es el mismo panel: lista
  con icono y título, selección con filo rojo y el contorno de la ventana elegida en rojo.
- **Paneles del sistema:** el menú de energía (`command-os-power`: bloquear · reiniciar · apagar, con
  confirmación) es un panel Wofi pequeño sin buscador, con el filo rojo en la opción elegida; se abre
  con Super+Escape o con el botón 󰐥 al final de la barra. La ayuda de atajos (`command-os-keys`,
  Super+F1) usa el mismo panel en dos columnas. El mezclador de volumen (clic en `vol`) es pavucontrol
  de 460×340 sin barra de título, fijado bajo la barra arriba a la derecha; otro clic lo cierra.
- **Sin blur ni transparencias** en el escritorio: la GPU del Pi 5 no da para blur fluido y el HUD
  se lee mejor opaco. El brillo se hace con sombras y `text-shadow`.
- **Fondo** (`build/make-wallpaper.py`): Void con la matriz de puntos de 26 px, líneas de escaneo
  sutiles, halo rojo muy tenue abajo, escuadras rojas en las esquinas y el rótulo `cmd-os // command os`
  en cian con su regla, arriba a la izquierda y con aire bajo la barra. Sin wordmark ni textos de
  estado: el logo ya está en la barra, el arranque y el bloqueo.

## Movimiento

Curva `cubic-bezier(0.16, 1, 0.3, 1)` (`--ease-out`), sin rebotes. Entradas secas (200–300 ms).
**labwc no anima ventanas** (abrir, cerrar y mover son inmediatos): es parte de su ligereza. El
movimiento del escritorio vive en los paneles: el lanzador y el menú de energía entran con un fundido
y un desliz corto de 200–220 ms, y la barra hace transiciones de color en los espacios, la barra de
tareas y el logo.
**Firma de arranque:** el wordmark se revela de izquierda a derecha con un cursor cian en el borde,
después la barra roja se extiende desde la izquierda con su halo; ~1,1 s, 28 fotogramas, tres de
ellos con glitch (franjas desplazadas y aberración roja/cian). El último queda limpio
(`os/branding/plymouth/`, fotogramas con `build/make-plymouth.py`). Debajo, solo una barra de progreso
fina en rojo y, bajo ella, una consola de 6 líneas con los servicios que arranca systemd (la más
reciente en hueso, las anteriores apagándose hacia Smoke). Es el único texto del arranque; Esc pasa
al modo detalles de Plymouth, para soporte. Al apagar, solo el wordmark.
Del encendido al escritorio no aparece texto del cargador, del kernel ni de systemd.
En VM, `install.sh` quita el halo y las sombras de las ventanas (`~/.config/labwc/themerc-override`).

## Sonido

Pendiente.

## Objeto

Pendiente: depende de la carcasa del hardware.

## Voz

Español, tuteo, minúsculas y tono terminal: `› bloqueado`, `contraseña`, `sin red`. Sin exclamaciones
ni emojis.

## Anclas de Command

| #   | Ancla                      | Cómo se cumple                                                                                                                    | Estado                                       |
| --- | -------------------------- | --------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| 1   | Logotipo con su barra      | Símbolo C en Waybar y bloqueo; wordmark en el splash; siempre con la barra roja.                                    | ✔ verificado en VM (labwc, 2026-10-05)       |
| 2   | Firma de arranque          | Plymouth: letras de izquierda a derecha y luego la barra. ~1,1 s. **Saltable con una tecla: no implementado.**                    | parcial (splash visto; animación sin medir)  |
| 3   | Un solo punto rojo         | El rojo es el primario del HUD pero sigue marcando lo activo (marco de ventana, espacio de trabajo, foco, selección); los datos van en cian. El punto rojo físico depende del hardware. | pantalla ✔ verificado en VM · objeto pendiente |
| 4   | Voz                        | Textos de bloqueo, `issue` y `motd` en tono terminal.                                                                             | ✔                                            |
| 5   | Nombre y código            | `os-release` (`VARIANT="CMD-OS"`), `/etc/issue` y `motd`. Falta una pantalla de información del sistema.                           | parcial                                      |
| 6   | Principios como requisitos | Base abierta (Arch + dotfiles en el repo). Resto depende del hardware.                                                            | pendiente                                    |
| 7   | Por dentro también         | Serigrafía de la placa.                                                                                                           | pendiente (hardware)                         |
| 8   | Lo impreso es de la marca  | Caja, manuales, etiquetas.                                                                                                        | pendiente                                    |

## No hacer

- Recolorear la barra del logo (siempre Signal Red) ni poner el wordmark sobre fondos con ruido fuerte.
- Magenta, morado o degradados arcoíris: la paleta es rojo + cian, con amarillo solo para avisos.
- Colores neón saturados (`#FF3B2F`, `#3FE0E8`, `#FCEE0A`) o halos fuertes: el tono es el de los
  menús de 2077, contenido.
- Blur, glassmorphism o transparencias en el escritorio.
- Glitch o animaciones en bucle durante el uso: el glitch es solo del arranque.
- Cian para lo activo o rojo para datos: cada uno tiene su papel.
