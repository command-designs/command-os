# Command OS — Lenguaje del producto

Cómo se ve, se mueve y suena Command OS (`CMD-OS`). Es el sistema de un dispositivo: su interfaz es la
de la **marca v2 de Command** con su **lenguaje HUD** (`BRAND.md` 2.1 §§ 3–9, adaptada a la pantalla
según § 12.3) y lo une a Command el cumplimiento de las anclas de § 12.1 (tabla al final). Fuente de
la marca: <https://github.com/command-designs/command-web> (`BRAND.md`, `tokens.css`). **Referencia
visual: `lenguaje.html`** (<https://commandlab.dev/lenguaje>); si `BRAND.md`, el kit o este documento
dicen otra cosa, manda ella. Por qué esta marca y qué se descartó: `docs/decisiones/README.md` (2026-10-19).

## Idea

La interfaz de una **máquina que funciona**: precisa, sobria y legible, como el panel de un
instrumento bien hecho. Casi monocromo, el rojo como señal, líneas finas, esquinas en chaflán y
medidores honestos. Lo retro viene del medio (la terminal, la línea de comandos), no de un disfraz.

**Regla de función** (BRAND § 7.1, obligatoria): todo lo que se ve nombra algo, informa de un estado,
mide algo real o es una acción. Nada decorativo en pantalla, y un estado nunca va solo en color. Lo que
le falte al lenguaje se añade en command-web, no se inventa aquí.

## Color

**Paleta v2** (`tokens.css` de command-web, la fuente que manda), escrita a mano en cada archivo de
tema: `themerc` y botones de labwc, Waybar, Wofi, swaync, hyprlock y swaylock, Kitty, GTK 3/4,
`greeter/command.css`, prompt de bash, fastfetch, Plymouth, tema de GRUB y los scripts de `build/`.
**`tests/marca.sh` falla si aparece un color fuera de ella** (o de los extra permitidos) o algo del
estilo anterior:

| Token       | Hex                   | Uso                                                                  |
| ----------- | --------------------- | -------------------------------------------------------------------- |
| Void        | `#0E0E0E`             | fondo; fondo de listas y campos                                      |
| Graphite    | `#151515`             | superficies (paneles, lanzador, notificaciones, ventanas de apps)    |
| Slate       | `#1F1F1F`             | lo seleccionado, hover, barra de título activa, diálogos             |
| Steel       | `#2A2A2A`             | bordes y separadores                                                 |
| Iron        | `#3A3A3A`             | selección de texto en la terminal, filo del lanzador y de los botones |
| Bone        | `#EDEBE6`             | texto principal                                                      |
| Ash · Smoke | `#A3A09A` · `#85827C` | texto secundario / etiquetas y datos apagados                        |
| Signal Red  | `#A51500`             | **superficies**: barra del logo, botón principal (texto blanco), texto seleccionado |
| Red Hot     | `#F5482C`             | **texto, iconos, foco y las líneas de lo activo** (1–2 px): filo de la ventana activa, campo enfocado, enlaces, barra de la selección, subrayado del activo, crítico |
| Red Deep    | `#6E0E00`             | botón principal pulsado                                              |
| OK · Warn   | `#3DDC84` · `#FFB020` | estados, **siempre con su texto** (cifra, `UPD N`, «acceso denegado») |
| Hover rojo  | `#B81A02`             | relleno del botón principal al pasar por encima (BRAND 2.1 § 7)      |
| Seleccionado | `#1A1311`            | fondo de la tarjeta o fila seleccionada, con filo Red Hot (2.1 § 7)  |

**Tokens HUD** (BRAND 2.1 § 7, aún fuera de `tokens.css`): `--holo` Bone al 55 % (trazo del plano
holográfico), `--holo-dim` Bone al 18 % (sus guías; sustituye a `--line-guide`), `--glow` Red Hot al
55 % (halo de la señal y del LED rojo) y `--glow-soft` Red Hot al 22 % (halo del cabezal de la firma).

El rojo es una señal (≤ 2 % de la pantalla): lo activo, el foco, la acción principal y la barra del
logo; los datos van en neutros. **Colores extra**, solo donde hacen falta y con su motivo en
`tests/marca.sh` (`EXTRA`): hoy, los colores 4, 5 y 6 de ANSI de la terminal (Kitty), apagados casi a
gris, porque los programas los usan con significado (`ls`, `git diff`) y la marca no los tiene.

## Letra

BRAND § 5: **JetBrains Mono** en barra, terminal, títulos de ventana, Alt+Tab, etiquetas y rótulos de
los menús; **Geist** en lanzador, menús y notificaciones; **Oxanium** en titulares (paneles,
asistente, inicio de sesión), el reloj de la barra y la hora del bloqueo. Nunca mono para titulares.
Como en `lenguaje.html`: las etiquetas, lecturas, estados y botones en mono van en **mayúsculas**,
peso 500 y espaciado de 0,14 em (el CSS de GTK no tiene `text-transform`: el texto lo pasan a
mayúsculas `comun.fila` y `comun.boton`, y las traducciones siguen en minúsculas); los titulares en
Oxanium 600 con −0,02 em. Los mensajes en tono terminal (`› sistema listo`) siguen en minúsculas
(BRAND § 2). Oxanium y Geist no están en los repos de Arch y se instalan desde `os/branding/fonts/` (licencia OFL
incluida).

## Forma

BRAND § 6. **Chaflán**: esquinas superior izquierda e inferior derecha cortadas a 45°, con el filo de
1 px siguiendo el corte, en los tamaños de `tokens.css`: paneles (14 px: inicio de sesión, asistente,
notificaciones, menú de energía y demás paneles de wofi), menús y popovers de las apps (14 px),
lanzador (20 px), botones con texto (10 px) y pistas (6 px). El resto, esquinas vivas (radio 0) y
bordes de 1 px; radio de 2 px solo en los campos de texto (y redondos los botones de radio y los
deslizadores). **Escuadras** (cuatro esquinas Red Hot de 1 px y 10 px) solo en la zona principal del
bloqueo (hora y contraseña) y del inicio de sesión y el asistente (el panel). Lo seleccionado va en
Slate con la barra Red Hot de 2 px a la izquierda, como la paleta de `lenguaje.html` (las líneas finas
que marcan lo activo son Red Hot; Signal Red queda para superficies); una tarjeta o fila elegida sin
barra, en `#1A1311` con filo Red Hot (Alt+Tab, GRUB). Al pasar el ratón, el filo pasa a Red Hot (y el
texto del botón a blanco); el botón principal se rellena de `#B81A02`. Sin halos (solo en la señal,
ver abajo).

- **Cómo:** el CSS de GTK no tiene `clip-path`. El chaflán es un `border-image` con SVG de nueve partes
  (`build/make-chaflanes.py` → `/usr/share/command-os/chaflanes/`) y el centro, que GTK no pinta, un
  degradado liso del tamaño menos las esquinas. hyprlock no tiene imágenes de borde: sus escuadras son
  8 rectángulos (`shape`). `tests/marca.sh` comprueba que los SVG están al día.
- **Sin chaflán** (no se puede): los menús de labwc, Alt+Tab y los marcos de ventana (labwc solo dibuja
  rectángulos), los popovers con flecha de GTK 3 y los botones en grupos unidos, de barras de
  herramientas o de solo icono (el corte rompería la forma).

## Elementos del lenguaje (BRAND § 7.2)

- **Paneles con chaflán:** inicio de sesión, asistente, paneles del sistema, notificaciones y lanzador.
  Dentro, titular en Oxanium, etiquetas en Smoke y lecturas.
- **Lecturas** (`.readout`): la telemetría de la barra (etiqueta en Smoke, valor en Ash), fastfetch y
  «acerca de cmd-os».
- **Medición** con un valor real detrás: el anillo (`.ring`) y la barra de 2 px (`.meter`) del
  arranque, con el mismo avance y sin porcentaje porque es una estimación, la lista de comprobaciones
  de arranque (`.diag`) con su contador y la barra de progreso de las notificaciones.
- **Retícula de puntos** de 26 px y **rejilla de 64 px** del plano técnico, en los fondos.
- **Paleta de comandos:** el lanzador (BRAND § 7.2), sin el velo que atenúa la vista porque aquí no hay
  transparencias.
- **Halo** (brillo suave, BRAND 2.1 § 7.2): solo en la barra del logo, el trazo rojo de un plano y su
  llamada, el cabezal de la firma y los LED de estado (cada uno con su color, `0 0 .6em`). Nunca en
  texto, paneles ni bordes: `tests/marca.sh` falla con un `text-shadow`, una sombra de hyprlock o una
  sombra de color con desenfoque fuera de un selector de LED (las negras son sombras de flotantes).
- **Iconos:** Papirus-Dark con carpetas grises (`command-os-icon-folders`; el rojo queda para lo
  activo). Iconografía propia, pendiente (BRAND § 12.3 la deja libre).

## Escritorio

- **Ventanas (labwc, tema `Command` en `os/branding/labwc/`):** flotantes, con barra de título y
  botones a la derecha (minimizar · maximizar · cerrar). **Una sola barra de título para todas**: 32 px;
  la activa, filo Red Hot de 1 px y barra plana en Graphite con el título en JetBrains Mono negrita;
  la inactiva, filo Steel, barra Void, título y botones en Smoke. Las dos, con una sombra oscura corta
  que las separa del fondo. Botones dibujados a propósito (`build/make-labwc-buttons.py`, 36×32):
  maximizar son escuadras; al pasar por encima, Bone sobre Steel, y cerrar en blanco sobre Signal Red.
  Las apps GTK 3/4 que se dibujan su propia cabecera (Bazaar, diálogos) copian esa barra en `gtk.css`
  con los mismos SVG (`botones/`) y el filo por dentro (`outline`), y sin la atenuación de libadwaita
  al perder el foco; Firefox usa la de labwc (`docs/notas/escritorio.md` § «Ventanas iguales»). Arrastrar al
  borde encaja la ventana (arriba maximiza; lados, media pantalla) con una guía Bone translúcida y
  filo Red Hot.
- **Apps (GTK 3/4 y Qt):** mismo tema que el escritorio, sin ventanas blancas. Base `adw-gtk3-dark`
  recoloreada en `~/.config/gtk-3.0/gtk.css` y `gtk-4.0/gtk.css` (colores con nombre y variables de
  libadwaita): ventana y cabeceras en Graphite (la cabecera con filo Steel debajo), listas en Void,
  menús y popovers en Slate con chaflán y filo Steel, selección en Slate con la barra Red Hot a la
  izquierda, texto seleccionado en Signal Red con texto blanco, botones con texto con chaflán (en
  Graphite con filo Iron, Red Hot al pasar; el principal en Signal Red, `#B81A02` al pasar), botones
  que se quedan pulsados con el texto en Red Hot, casillas marcadas en Bone, foco y enlaces en Red Hot,
  OK y Warn para estados; el principal desactivado, como cualquier botón desactivado (sin rojo). Los
  rótulos de sección (título de un grupo de ajustes, `.caption-heading`) en mono 500 y Smoke con
  0,16 em, como las etiquetas de `lenguaje.html`; no todo `.heading`, que las apps usan también para
  nombres. Los SVG de los
  chaflanes van copiados junto a las hojas (`~/.config/gtk-*/chaflanes/`) para que también los vean
  las apps Flatpak. Qt sigue a GTK (`QT_QPA_PLATFORMTHEME=gtk3`). `dconf` pone el modo oscuro para
  todo el sistema (Firefox y portales incluidos).
- **Barra (Waybar):** como la barra superior de la app de `lenguaje.html` (§ 03): 36 px, Graphite con
  filo Steel y lecturas mono en mayúsculas (peso 500, 0,14 em). A la izquierda, el logo en su celda
  cuadrada (filo Steel a la derecha; clic: aplicaciones), las fijadas y una celda con un icono por
  ventana. Los iconos, como el carril (`.a-rail`): apagados en reposo (opacidad 0,55: GTK 3 no tiene
  filtro de gris) y a color al pasar el ratón y en la ventana activa, que va en Slate con filo Steel y la
  línea Red Hot debajo; las minimizadas, más apagadas. En el centro, fecha apagada y hora en Oxanium. A
  la derecha, celdas separadas por un filo Steel y sin cajas dentro: el aviso `UPD N`, los escritorios,
  la telemetría (`CPU`, `TMP`, `MEM`; oculta de serie), **el grupo de estado** (`NET` con la señal wifi,
  `BT` (`OFF`, `ON` o los conectados; oculto sin adaptador), `VOL`, `BAT` con el tiempo que queda), la
  bandeja (solo apps de terceros; sin iconos no se ve) y el botón de energía. El grupo de estado es una
  sola pieza, como la lectura «sincronizado» de la referencia: se ilumina entero en Slate al pasar el
  ratón y el clic en cualquier lectura abre el centro de control; el clic derecho va a lo de cada una.
  Warn al pasar el umbral de aviso, Red Hot al crítico, siempre con la cifra. **LED de estado** con su
  halo (`.led`), solo cuando dicen algo y con su texto: verde con red, Red Hot sin red (`SIN RED`) y Warn
  con una versión nueva de command-os (`UPD N`). Son un degradado radial de fondo (Waybar no tiene otro
  elemento donde ponerlos); los textos traducidos van en mayúsculas con `text_transform` de Pango.
- **Centro de control** (`command-os-centro`): un panel con chaflán que cuelga bajo la barra, a la
  derecha, sobre Void. Mosaicos para Wi-Fi y Bluetooth con filo Steel; encendido, el mosaico va en Slate
  con el icono en Red Hot. Debajo, volumen y brillo, la batería y el botón a Ajustes. La flecha de un
  mosaico abre la lista de redes o de dispositivos dentro del mismo panel. Se cierra al hacer clic
  fuera, con Escape o con otro clic en la barra.
- **Ajustes** (`command-os-ajustes`): ventana con la lista de secciones a la izquierda y la sección a la
  derecha, con la forma de las demás apps GTK de la marca; lo avanzado, aparte, en cada sección.
- **Escritorios:** uno de serie, y la barra no enseña nada. Super+Ctrl+D (o clic derecho →
  `escritorios`) crea otro, hasta 4, y salta a él; entonces aparecen sus números (`01 02…`) a la
  derecha de la barra, el activo en Red Hot sobre Slate con la línea Red Hot debajo. Super+Ctrl+F4 quita
  el último y sus ventanas pasan al 01 (`command-os-desktops`).
- **fastfetch:** la C de Command con su barra en Signal Red (`build/make-fastfetch-logo.py`), claves en
  castellano y minúsculas en Smoke, separador `›` Red Hot, valores en Bone y porcentajes en OK, Warn o
  Red Hot según el nivel; sin la tira de colores del final. Configuración de sistema en
  `/etc/xdg/fastfetch/`.
- **Menús de labwc** (clic derecho en el escritorio o en la barra de título): Graphite con filo Steel,
  opción activa en Slate con el texto en Red Hot, rótulos de sección en JetBrains Mono y Smoke sobre
  Void y textos en la voz de la marca (`aplicaciones`, `ajustes`, `mover a`…). **Alt+Tab** es el mismo
  panel: lista con icono y título, la elegida como una tarjeta seleccionada (`#1A1311` con filo Red Hot)
  y el contorno de la ventana elegida en Red Hot.
- **Lanzador** (Wofi, `command-os-launcher`): panel con chaflán de 20 px y filo Iron, fila de búsqueda
  sin caja con la lupa en Red Hot y una línea Steel debajo, entradas en Ash y la activa en Bone sobre
  Slate con la barra Red Hot a la izquierda.
- **Paneles del sistema:** el menú de energía (`command-os-power`: bloquear · reiniciar · apagar, con
  confirmación) es un panel Wofi pequeño con chaflán y sin buscador, con la opción elegida en Slate y
  la barra Red Hot; se abre con Super+Escape o con el botón 󰐥 al final de la barra. La ayuda de atajos
  (`command-os-keys`, Super+F1) usa el mismo panel en dos columnas; «acerca de cmd-os»
  (`command-os-about`, Super+F2 o el menú del escritorio) también: nombre, paquete, Arch validado,
  hardware y si se puede volver atrás. El mezclador de volumen (clic derecho en `vol`) es pavucontrol de
  460×340 sin barra de título, fijado bajo la barra arriba a la derecha; otro clic lo cierra.
- **Inicio de sesión, asistente y paneles** (`greeter/command.css`): panel Graphite con chaflán y filo
  Steel dentro de las escuadras de la zona principal, titular en Oxanium, etiquetas mono en Smoke y
  mayúsculas, campo en Void con el foco Red Hot (los desplegables, como la cuenta, son un campo igual)
  y botones con chaflán en mono mayúsculas (el principal en Signal Red con texto blanco).
- **Bloqueo** (hyprlock): hora en Oxanium y campo de contraseña dentro de las escuadras, sobre el fondo
  `void`; encima, `SESIÓN BLOQUEADA` como un eyebrow (mono 500 en mayúsculas, Red Hot). La línea de
  estado de arriba (`command-os-status --pango`) y el aviso de contraseña incorrecta van también en
  mayúsculas, como lecturas. Si hyprlock falla, `command-os-lock` usa su configuración de emergencia y, como último
  recurso, swaylock con los mismos colores.
- **Notificaciones** (swaync, `os/dotfiles/swaync/`): panel Graphite con chaflán y filo Steel (Red Hot al
  pasar el ratón y en la crítica, que no se cierra sola), título en Bone, cuerpo en Ash, sin la
  hora; barra de progreso de 2 px en Bone sobre Steel (el medidor de `lenguaje.html`). Super+N las cierra todas.
- **Sin blur ni transparencias, y halos solo en la señal**: la GPU del Pi 5 no da para blur fluido y la interfaz se lee
  mejor opaca. Las ventanas y paneles flotantes llevan una sombra oscura corta. En VM, `install.sh`
  quita el halo y las sombras de las ventanas (`~/.config/labwc/themerc-override`).

## Fondos

`build/make-wallpaper.py`: el lenguaje de la web (BRAND § 7.2), sin nada que decore (ni lecturas, ni
números de serie, ni adornos inventados). Dos para elegir (`command-os-wallpaper elegir`, o ajustes →
fondo de pantalla en el menú del escritorio):

- **retícula** (de serie): la retícula de puntos de 26 px (Steel sobre Void) con máscara radial, la C
  en el centro y un degradado rojo radial al 14 % detrás de ella, como el héroe de la web.
- **plano**: el plano holográfico del héroe de `lenguaje.html` (§ 02) con la construcción real del
  símbolo, sobre la retícula de puntos, la rejilla de 64 px (que pasa por su esquina) y el degradado
  rojo al 14 %: el contorno de la C en `--holo`, las guías de sus medidas (tronco, brazos, hueco y
  barra) y el área de respeto discontinua (¼ del ancho) en `--holo-dim`, y **llamadas** quebradas que
  terminan en una etiqueta mono 500 en mayúsculas con la medida de la pieza en unidades del `viewBox`
  (1158 × 1237). La barra es lo único rojo del símbolo; su llamada, la única en Red Hot, con el halo de
  `#hudglow`. Las etiquetas van en castellano (el idioma principal de la marca) en todos los idiomas.
- **void**: Void con la retícula muy tenue y sin rojo; solo para el bloqueo, GRUB y el asistente, que
  ya llevan el logo encima.

La barra del símbolo es siempre Signal Red y lleva su halo (2 % del ancho, 55 %). En PNG sin
grano (de 30 a 110 KB).

## Movimiento

BRAND § 9. Solo las curvas de la marca: `cubic-bezier(0.16, 1, 0.3, 1)` (`--ease-out`, casi todo),
`(0.65, 0, 0.35, 1)` (`--ease-in-out`) y `(0.2, 0.9, 0.1, 1.25)` (`--ease-snap`); sin rebotes ni
curvas de otros sistemas. Duraciones de la marca: 160 ms (`--dur-fast`) para hover, foco y cambio de
estado, y 280 ms (`--dur-base`) para lo que entra. Solo al entrar, al salir o al pasar el ratón:
**nada se mueve en reposo** (ligereza). `tests/marca.sh` falla con otra curva o con una animación en
bucle (`infinite`). **labwc no anima ventanas** (abrir, cerrar y mover son inmediatos): eso queda para
la tanda 3 (`ROADMAP.md`).

- **Apps GTK 3 y 4** (`gtk.css`): botones, campos, filas, casillas, interruptores, pestañas y menús
  cambian el color y el relleno en 160 ms. El foco de los campos funde su filo Red Hot.
- **Barra:** el color de los iconos, los espacios y el grupo de estado cambia en 160 ms. La línea
  Red Hot de lo activo (ventana y escritorio) es el subrayado de § 9.2.3: un fondo de 2 px que crece
  desde la izquierda en 280 ms y se va por la derecha (solo se anima el ancho; la posición salta). El
  aviso de una versión nueva aparece una vez con un fundido de 280 ms.
- **Centro de control:** entra con un fundido y 8 px de desliz hacia abajo en 280 ms, como el panel del
  inicio de sesión; se cierra sin animación (la ventana desaparece al perder el foco).
- **Lanzador y menú de energía** (wofi): entran con un fundido y un desliz corto de 200–220 ms; la fila
  elegida cambia en 160 ms.
- **Notificaciones:** entran con el desliz y el fundido de swaync (`transition-time` 280 ms); el hover
  del panel y de sus botones, en 160 ms.
- **Inicio de sesión y asistente:** el panel entra con sus escuadras una sola vez (fundido y 8 px de
  desliz, 280 ms); sus campos y botones, como las apps GTK 4.
- **Bloqueo:** entra con un fundido de 0,4 s y su campo de contraseña cambia de color con la misma
  curva (filo Red Hot; Ash comprobando, Warn si falla o si las mayúsculas están activadas, con el
  número de intentos).

Límites medidos en la VM (2026-10-21), que no se arreglan con CSS:

- **GTK no anima el `border-image`.** El filo de los chaflanes y su banda de 11 px cambian de golpe:
  el botón principal funde su relleno (de Signal Red a #B81A02) en vez del barrido de § 9.2.4. Con
  dos capas de fondo, el barrido solo se veía en la franja central, entre las bandas del chaflán.
- **swaync** usa su propia curva (fija en su código, no se configura) y, al irse la última
  notificación, cierra la ventana sin animación de salida.

- **Firma de arranque** (BRAND § 9.1, versión corta; `os/branding/plymouth/`): sobre Void liso, el
  contorno del símbolo C se traza en Bone (1 px, la forma real del logo) y se rellena de izquierda a
  derecha; su barra Signal Red se extiende con su halo y el wordmark se revela de izquierda a derecha
  con un cabezal Red Hot, y después su barra. 2,65 s (~2,8 s medidos en la VM del primer fotograma al
  último), con las curvas de la marca. Cualquier tecla la salta al final; Esc pasa al modo detalles de
  Plymouth, para soporte. Al apagar, solo el logo ya completo.
- **Arranque con diagnóstico** (BRAND § 9.2), como la pantalla de carga de `lenguaje.html` (§ 04):
  acabada la firma, el símbolo pasa en 0,6 s al centro de un anillo a la izquierda y el wordmark se
  encoge hasta el rótulo de arriba (`command · CMD-OS`), y aparece el resto:
  - arriba a la derecha, `ESC · DETALLES` (la firma se salta con cualquier tecla, sin aviso);
  - el anillo (pista Steel, avance Red Hot) sobre una retícula de puntos con máscara radial;
  - a la derecha, las comprobaciones reales, en orden (disco del sistema, sistemas de archivos,
    dispositivos, servicios básicos, red, inicio de sesión), con el número, el nombre en Geist y el
    estado en mono (EN ESPERA atenuada, EN CURSO en Red Hot, OK en verde, ERROR en Red Hot), y el
    contador de hechas (`4 / 6`) en la cabecera;
  - abajo, lo que se está haciendo (`ARRANCANDO LA RED`; `SISTEMA LISTO` al llegar al inicio de
    sesión; el fallo, en Red Hot, con «esc: detalles»), la barra de 2 px en Bone sobre Steel y un
    `CONSEJO` con un atajo real, uno al azar en cada arranque.

  El anillo y la barra muestran el mismo avance de Plymouth y nunca retroceden; **sin porcentaje**
  (decisión del usuario): es una estimación por el tiempo de arranques anteriores (BRAND § 9.3), y la
  cifra real es el contador. Las comprueba `lib/diagnostico-arranque` con systemd
  (`docs/notas/arranque-e-imagenes.md`). Con el disco cifrado, la contraseña se pide en el sitio de la
  lista. Plymouth no dibuja arcos: el avance del anillo son 400 puntos Red Hot que se encienden.
- **GRUB** (tema de `apply-boot`): el menú solo aparece con Esc; lleva el fondo `void`, el panel con
  chaflán, las entradas en Geist con la elegida en Slate y la barra Red Hot (la paleta) y los rótulos
  (cuenta atrás y teclas) en mono 500 y mayúsculas.

Del encendido al escritorio no aparece texto del cargador, del kernel ni de systemd.

## Sonido

Libre en cada dispositivo (BRAND § 12.3). El de Command OS es un instrumento de medida preciso y
sobrio, como la interfaz (`build/make-sounds.py`, síntesis propia): tonos casi puros (seno con un
segundo armónico breve en el ataque), ataque de 2 ms y caída limpia, sin rebotes, como `--ease-out`.
Sin ruido, sin saturación y sin nada al azar. Una sola tónica (La) con quintas, cuartas y octavas, los
tiempos de la marca (90 y 160 ms) y una sala casi seca.

- **boot** (inicio de sesión): La4, Mi5 y La5 escalonados 160 ms; el último se queda con La3 suave
  debajo. ~1,5 s.
- **notify** (swaync, al llegar una notificación): dos notas cortas que suben una cuarta (La5, Re6).
  **critical**: Re6 tres veces cada 160 ms, más brillante; la urgencia la da la repetición, no la
  distorsión.
- **lock**: dos notas que bajan una quinta (Mi6, La5). **unlock**: la misma figura hacia arriba.
- **tick** (teclas de volumen): un toque de 90 ms (Mi7), como el paso de un mando de precisión.

## Objeto

Pendiente: depende de la carcasa del hardware (forma, materiales y acabados son libres, BRAND § 12.3).

## Voz

BRAND § 2: español, tuteo, minúsculas y tono terminal: `› bloqueado`, `contraseña`, `sin red`. Sin
exclamaciones ni emojis. Un error dice qué pasa y qué hacer.

## Anclas de Command

BRAND § 12.1; la pantalla sigue § 12.3 (pantalla en color: tokens de § 4 y tipografías de § 5).

| #   | Ancla                      | Cómo se cumple                                                                                                                    | Estado                                       |
| --- | -------------------------- | --------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| 1   | Logotipo con su barra      | Símbolo C en Waybar, bloqueo y fondos; símbolo y wordmark en la firma de arranque; siempre con la barra Signal Red. En el objeto, pendiente del hardware. | pantalla ✔ verificado en VM · objeto pendiente |
| 2   | Firma de arranque          | Plymouth: versión corta de la secuencia (trazado → relleno → barra → wordmark), 2,65 s; cualquier tecla la salta (Esc, modo detalles). Después, las comprobaciones de arranque. | ✔ verificado en VM (2026-10-19; ~2,8 s medidos) |
| 3   | Un solo punto rojo         | En pantalla, el rojo es una señal: solo lo activo (filo de la ventana, escritorio, foco, selección, botón principal) y la barra del logo; los datos van en neutros. El punto rojo físico depende del hardware. | pantalla ✔ verificado en VM · objeto pendiente |
| 4   | Voz                        | Textos del sistema (bloqueo, paneles, `issue`, `motd`) en tono terminal y en castellano de serie; sonidos sobrios, sin alarmas ni efectos. | ✔                                            |
| 5   | Nombre y código            | `os-release` (`VARIANT="CMD-OS"`), `/etc/issue` y `motd`. Pantalla «acerca de cmd-os» (Super+F2). Placa y caja, con el hardware.  | pantalla ✔ verificado en VM (2026-10-07) · placa y caja pendientes |
| 6   | Principios como requisitos | Documentado: base abierta (Arch y la configuración en el repo) y guías (`INSTALAR.md`, `docs/`). Reparable, duradero y táctil dependen del hardware. | pendiente (hardware)                         |
| 7   | Por dentro también         | Serigrafía de la placa.                                                                                                           | pendiente (hardware)                         |
| 8   | Lo impreso es de la marca  | Caja, manuales, etiquetas.                                                                                                        | pendiente                                    |

Recomendado (§ 12.2): el sonido de arranque es propio (`boot`), pero suena al entrar en la sesión y no
con la firma: Plymouth no tiene audio.

## No hacer

- Recolorear la barra del logo (siempre Signal Red) ni poner el wordmark sobre fondos con ruido fuerte.
- Colores fuera de la paleta v2, salvo los extra documentados en `tests/marca.sh`; Signal Red para
  texto (no da contraste) o Red Hot para superficies.
- Halos fuera de la señal (barra del logo, trazo rojo del plano, cabezal de la firma, LED), y nunca
  en texto, paneles ni bordes; blur, glassmorphism, neones o transparencias.
- Esquinas redondeadas o píldoras (solo 2 px en los campos de texto); chaflanes en otro tamaño que los
  de `tokens.css` (6 · 10 · 14 · 20 px) o en las otras dos esquinas.
- Efectos de interferencia, parpadeos, letras que se barajan o animaciones en bucle por adorno
  (BRAND § 7.2 y § 9.3).
- Un estado solo con color: siempre con su texto.
- Lecturas decorativas: números de serie, códigos o consolas inventados (regla de función).
- Estética retro de disfraz (BRAND § 1): lo retro viene del medio, no de efectos.
