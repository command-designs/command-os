# Command OS — Lenguaje del producto

Cómo se ve y se mueve Command OS (`CMD-OS`). Es el sistema de un dispositivo, así que su interfaz es
propia; lo une a Command el cumplimiento de las anclas de `BRAND.md` § 12 (tabla al final).
Fuente de la marca: <https://github.com/command-designs/command-web> (`BRAND.md`, `tokens.css`).

## Idea

Una máquina que funciona, con la **marca v2 de Command** (`BRAND.md` 2.0 §§ 3–9 y 12.3; referencia
visual en `lenguaje.html` de command-web): precisa, sobria y legible, como el panel de un instrumento
bien hecho. Casi monocromo, el rojo como señal, líneas finas y medidores honestos. Sustituye al HUD
estilo Cyberpunk 2077 (decisión del usuario, 2026-10-19; por qué, en `docs/decisiones.md`). Se aplica
por partes (`ROADMAP.md`): colores y letra ✔; chaflanes y escuadras, fondos, arranque y sonidos,
pendientes.

**Regla de función** (BRAND § 7.1, obligatoria): todo lo que se ve nombra algo, informa de un estado,
mide algo real o es una acción. Nada decorativo en pantalla. Lo que le falte al lenguaje se añade en
command-web, no se inventa aquí.

## Pantalla

- **Paleta v2** (`tokens.css` de command-web, la fuente que manda). Escrita a mano en cada archivo de
  tema: `themerc` y botones de labwc, Waybar, Wofi, Mako, hyprlock, Kitty, GTK 3/4,
  `greeter/command.css`, prompt de bash, fastfetch, Plymouth, tema de GRUB y los scripts de `build/`.
  **`tests/marca.sh` falla si aparece un color fuera de ella** (o de los extra permitidos):

  | Token       | Hex                   | Uso                                                                  |
  | ----------- | --------------------- | -------------------------------------------------------------------- |
  | Void        | `#0E0E0E`             | fondo; fondo de listas y campos                                      |
  | Graphite    | `#151515`             | superficies (paneles, lanzador, notificaciones, ventanas de apps)    |
  | Slate       | `#1F1F1F`             | lo seleccionado, hover, barra de título activa, diálogos             |
  | Steel       | `#2A2A2A`             | bordes y separadores                                                 |
  | Iron        | `#3A3A3A`             | selección de texto en la terminal                                    |
  | Bone        | `#EDEBE6`             | texto principal                                                      |
  | Ash · Smoke | `#A3A09A` · `#85827C` | texto secundario / etiquetas y datos apagados                        |
  | Signal Red  | `#A51500`             | **superficies y barras**: barra del logo, botón principal (texto blanco), barra de lo activo, progreso, texto seleccionado |
  | Red Hot     | `#F5482C`             | **texto, iconos y foco**: filo de la ventana activa, campo enfocado, enlaces, crítico |
  | Red Deep    | `#6E0E00`             | botón principal pulsado                                              |
  | OK · Warn   | `#3DDC84` · `#FFB020` | estados, **siempre con su texto** (cifra, `upd N`, «acceso denegado») |

  El rojo es una señal (≤ 2 % de la pantalla). **Colores extra**, solo donde hacen falta y
  documentados en `tests/marca.sh`: hoy, el azul, el magenta y el cian de la terminal (Kitty), apagados.
- **Tipografía** (BRAND § 5): JetBrains Mono en barra, terminal, títulos de ventana, Alt+Tab, etiquetas
  y rótulos de los menús; Geist en lanzador, menús y notificaciones; Oxanium en titulares (paneles,
  asistente, inicio de sesión), el reloj de la barra y la hora del bloqueo. Nunca mono para titulares. Oxanium y Geist no están en los
  repos de Arch y se instalan desde `os/branding/fonts/` (licencia OFL incluida).
- **Forma:** esquinas vivas (radio 0; los chaflanes llegan con «Marca v2 — forma» del ROADMAP), bordes de 1 px.
  Lo seleccionado va en Slate con la barra Signal Red a la izquierda; nada de brillos en el texto.
- **Ventanas (labwc, tema `Command` en `os/branding/labwc/`):** flotantes, con barra de título y
  botones a la derecha (minimizar · maximizar · cerrar) como en cualquier escritorio. La activa: filo
  Red Hot de 1 px y barra plana en Slate con el título en JetBrains Mono negrita. La inactiva: filo
  Steel, barra Void, título y botones en Smoke. Las dos, con una sombra oscura corta que las separa del
  fondo (sin halo rojo). Botones dibujados a propósito (`build/make-labwc-buttons.py`): maximizar son
  escuadras; al pasar por encima, Bone sobre Steel, y cerrar en blanco sobre Signal Red. Las apps que
  se dibujan su propia cabecera (GTK 4, Firefox) llevan el mismo filo desde `gtk.css`. Arrastrar al
  borde encaja la ventana (arriba maximiza; lados, media pantalla) con una guía Bone translúcida y
  filo Red Hot.
- **Apps (GTK 3/4 y Qt):** mismo tema que el escritorio, sin ventanas blancas. Base `adw-gtk3-dark`
  recoloreada en `~/.config/gtk-3.0/gtk.css` y `gtk-4.0/gtk.css` (colores con nombre y variables
  de libadwaita): ventana en Graphite, listas en Void, cabeceras en Void con filo Steel, menús en
  Slate con filo Steel, selección en Slate con la barra Signal Red a la izquierda, texto seleccionado
  en Signal Red con texto blanco, botón principal en Signal Red, foco y enlaces en Red Hot, OK y Warn
  para estados, esquinas vivas. Qt
  sigue a GTK (`QT_QPA_PLATFORMTHEME=gtk3`). Iconos Papirus-Dark con carpetas grises
  (`command-os-icon-folders`; el rojo queda para lo activo). `dconf` pone el modo oscuro para todo el
  sistema (Firefox y portales incluidos).
- **Barra (Waybar):** a la izquierda, logo (clic: aplicaciones) y barra de tareas con un icono por
  ventana (la enfocada en Slate con la barra Signal Red debajo, las minimizadas atenuadas); en el
  centro, fecha apagada y hora en Oxanium; a la derecha, los escritorios, la telemetría con su
  etiqueta en Smoke y el valor en Ash (cpu, temperatura, memoria, red con la señal wifi, volumen,
  batería con el tiempo que queda), la bandeja (red de nm-applet) y el botón de energía. Warn al
  pasar el umbral de aviso, Red Hot al crítico, siempre con la cifra.
- **Escritorios:** uno de serie, y la barra no enseña nada. Super+Ctrl+D (o clic derecho →
  `escritorios`) crea otro, hasta 4, y salta a él; entonces aparecen sus números (`01 02…`) a la
  derecha de la barra, el activo en Red Hot sobre Slate con la barra Signal Red. Super+Ctrl+F4 quita el último y sus ventanas pasan al 01
  (`command-os-desktops`).
- **fastfetch:** la C de Command con su barra en Signal Red (`build/make-fastfetch-logo.py`), claves
  en castellano y minúsculas en Smoke, separador `›` Red Hot, valores en Bone y porcentajes en OK,
  Warn o Red Hot según el nivel; sin la tira de colores del final. Configuración de sistema en
  `/etc/xdg/fastfetch/`.
- **Menús de labwc** (clic derecho en el escritorio o en la barra de título): Graphite con filo Steel,
  opción activa en Slate con el texto en Red Hot, rótulos de sección en JetBrains Mono y Smoke sobre
  Void y textos en la voz de la marca (`aplicaciones`, `ajustes`, `mover a`…). **Alt+Tab** es el mismo
  panel: lista con icono y título, selección con filo Red Hot y el contorno de la ventana elegida en
  Red Hot.
- **Paneles del sistema:** el menú de energía (`command-os-power`: bloquear · reiniciar · apagar, con
  confirmación) es un panel Wofi pequeño sin buscador, con la opción elegida en Slate y la barra
  Signal Red; se abre
  con Super+Escape o con el botón 󰐥 al final de la barra. La ayuda de atajos (`command-os-keys`,
  Super+F1) usa el mismo panel en dos columnas; «acerca de cmd-os» (`command-os-about`, Super+F2 o el
  menú del escritorio) también: nombre, paquete, Arch validado, hardware y si se puede volver atrás. El mezclador de volumen (clic en `vol`) es pavucontrol
  de 460×340 sin barra de título, fijado bajo la barra arriba a la derecha; otro clic lo cierra.
- **Sin blur, transparencias ni brillos** en el escritorio: la GPU del Pi 5 no da para blur fluido y
  la interfaz se lee mejor opaca. El halo es solo de la barra del logo; las ventanas y paneles
  flotantes llevan una sombra oscura corta.
- **Inicio de sesión, asistente y paneles** (`greeter/command.css`): panel Graphite con filo Steel,
  titular en Oxanium, etiquetas en Smoke, campo en Void con el foco Red Hot y el botón principal en
  Signal Red con texto blanco.
- **Fondos** (`build/make-wallpaper.py`; **pendiente de «Marca v2 — fondos» del ROADMAP**: aún con el estilo
  anterior): gráfica de producto, como la que traería de serie un
  ordenador de ese mundo; nada de paisajes. Tres para elegir (`command-os-wallpaper elegir`, o
  ajustes → fondo de pantalla en el menú del escritorio):
  - **interfaz** (de serie): corte diagonal con filo rojo, trama de semitono roja, wordmark gigante
    en contorno, la C con microtipografía de fabricante (`SYS.INTEGRITY … OK`, número de serie,
    código de barras) y dos cortes con glitch.
  - **núcleo**: la C como pieza de hardware oscura con filo de luz roja, la barra encendida y
    reflejada, pistas de circuito con señales rojas y cianes y un aro técnico.
  - **placa**: macro de la placa del cyberdeck con el chip serigrafiado (`CMD-OS C2077-A`) y
    desenfoque de cámara hacia los bordes.
  - **void**: Void con la matriz de puntos tenue y un resplandor rojo bajo; solo para el bloqueo y
    GRUB, que ya llevan el logo encima.
  La barra del símbolo es siempre Signal Red; su resplandor, el rojo de la marca. Los de escritorio
  van en JPEG q93 (el grano no comprime en PNG).

## Movimiento

Curva `cubic-bezier(0.16, 1, 0.3, 1)` (`--ease-out`), sin rebotes. Entradas secas (200–300 ms).
**labwc no anima ventanas** (abrir, cerrar y mover son inmediatos): es parte de su ligereza. El
movimiento del escritorio vive en los paneles: el lanzador y el menú de energía entran con un fundido
y un desliz corto de 200–220 ms, y la barra hace transiciones de color en los espacios, la barra de
tareas y el logo. El bloqueo entra con un fundido de 0,4 s y su campo de contraseña cambia de color
con la misma curva (filo Red Hot; Ash comprobando, Warn si falla o si las mayúsculas están
activadas, con el número de intentos).
**Firma de arranque** (pendiente de «Marca v2 — arranque» del ROADMAP, aún con el estilo anterior; ya en v2: fondo
Void, barra de progreso Signal Red sobre Steel y cursor de la contraseña en Red Hot): el wordmark se revela de izquierda a derecha con un cursor cian en el borde,
después la barra roja se extiende desde la izquierda con su halo; ~1,1 s, 28 fotogramas, tres de
ellos con glitch (franjas desplazadas y aberración roja/cian). El último queda limpio
(`os/branding/plymouth/`, fotogramas con `build/make-plymouth.py`). Debajo, solo una barra de progreso
fina en rojo y, bajo ella, una consola de 6 líneas con los servicios que arranca systemd (la más
reciente en hueso, las anteriores apagándose hacia Smoke). Es el único texto del arranque; Esc pasa
al modo detalles de Plymouth, para soporte. Al apagar, solo el wordmark.
Del encendido al escritorio no aparece texto del cargador, del kernel ni de systemd.
En VM, `install.sh` quita el halo y las sombras de las ventanas (`~/.config/labwc/themerc-override`).

## Sonido

(Pendiente de «Marca v2 — sonidos» del ROADMAP: aún con el estilo anterior; tienen que sonar como
la interfaz v2, un instrumento preciso y sobrio.)

Un aparato real, no un móvil ni un videojuego (`build/make-sounds.py`, síntesis propia): pitidos
digitales cortos, clics de transitorio como relés o botones, barridos de encendido y apagado y una sala
pequeña y seca, sin ecos largos.
- **boot** (inicio de sesión): golpe grave de encendido, ventiladores que arrancan (ruido con el
  filtro abriéndose), ráfaga de pitidos de datos y confirmación en dos tonos. ~2,5 s.
- **notify**: clic y dos tonos digitales cortos. **critical**: tres pulsos de alarma saturados.
- **lock**: barrido hacia abajo y cerrojo. **unlock**: cerrojo y barrido hacia arriba.
- **tick** (teclas de volumen): clic seco de botón.

## Objeto

Pendiente: depende de la carcasa del hardware.

## Voz

Español, tuteo, minúsculas y tono terminal: `› bloqueado`, `contraseña`, `sin red`. Sin exclamaciones
ni emojis.

## Anclas de Command

| #   | Ancla                      | Cómo se cumple                                                                                                                    | Estado                                       |
| --- | -------------------------- | --------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| 1   | Logotipo con su barra      | Símbolo C en Waybar y bloqueo; wordmark en el splash; siempre con la barra roja.                                    | ✔ verificado en VM (labwc, 2026-10-05)       |
| 2   | Firma de arranque          | Plymouth: letras de izquierda a derecha y luego la barra. ~1,1 s. Cualquier tecla salta la animación (Esc sigue siendo el modo detalles). | ✔ verificado en VM (2026-10-07; ~1,1 s medidos) |
| 3   | Un solo punto rojo         | El rojo es una señal: solo lo activo (filo de la ventana, espacio de trabajo, foco, selección, botón principal) y la barra del logo; los datos van en neutros. El punto rojo físico depende del hardware. | pantalla ✔ verificado en VM · objeto pendiente |
| 4   | Voz                        | Textos de bloqueo, `issue` y `motd` en tono terminal.                                                                             | ✔                                            |
| 5   | Nombre y código            | `os-release` (`VARIANT="CMD-OS"`), `/etc/issue` y `motd`. Pantalla «acerca de cmd-os» (Super+F2).                                 | ✔ verificado en VM (2026-10-07)              |
| 6   | Principios como requisitos | Base abierta (Arch + dotfiles en el repo). Resto depende del hardware.                                                            | pendiente                                    |
| 7   | Por dentro también         | Serigrafía de la placa.                                                                                                           | pendiente (hardware)                         |
| 8   | Lo impreso es de la marca  | Caja, manuales, etiquetas.                                                                                                        | pendiente                                    |

## No hacer

- Recolorear la barra del logo (siempre Signal Red) ni poner el wordmark sobre fondos con ruido fuerte.
- Colores fuera de la paleta v2 (cian, magenta, el rojo `#D13449` del estilo anterior), salvo los extra
  documentados en `tests/marca.sh`; Signal Red para texto (no da contraste) o Red Hot para superficies.
- Halos o `text-shadow` fuera de la barra del logo, blur, glassmorphism o transparencias.
- Glitch, parpadeos o animaciones en bucle por adorno (BRAND § 9.3).
- Un estado solo con color: siempre con su texto.
- Lecturas decorativas: números de serie, códigos o consolas inventados (regla de función).
