# Decisiones

Decisiones no obvias: qué se decidió, por qué y qué se descartó, para no reabrirlas. Las anteriores
al 2026-10-07 están repartidas por `docs/` y `AGENTS.md` («Qué se probó y qué se descartó»).

## 2026-10-19 — Instalar aplicaciones (`docs/notas/escritorio.md` § «Instalar aplicaciones»)

- **Tienda de Flatpak con Flathub, no de pacman.** Las apps de Flatpak van aparte del sistema: instalar o
  actualizar una nunca toca la base de datos de pacman, la fecha validada ni el bloqueo, así que no
  puede romper una actualización. Descartado: pamac (AUR, fuera de los repos oficiales; instala del AUR
  contra un Arch que no es el validado y hace actualizaciones parciales) y PackageKit con GNOME Software
  o Discover (sincroniza la base de datos de pacman por su cuenta y se salta el orden de
  `command-os-update`; Discover trae KDE).
- **Bazaar como tienda** (aprobado por el usuario frente a GNOME Software): hecha solo para Flathub,
  rápida, la usan Bazzite y Bluefin, abre `.flatpakref` y `appstream://` y avisa de los permisos de cada
  app. Coste: arrastra `webkitgtk-6.0`. GNOME Software (sin WebKit) está pensada para GNOME (firmware,
  sistema) y es más lenta. Bazaar como Flatpak se descartó: más de 1 GB de runtimes en la instalación,
  con red dentro de un gancho de pacman.
- **Fecha validada 2026/10/05 → 2026/10/18.** En la foto del 2026/10/05, el Bazaar 0.9.6 de Arch venía
  compilado contra libdex 1.2 (llegó a `extra` el 2026-10-07) y no arrancaba (`undefined symbol:
  dex_limiter_run`). Se validó en la VM (actualizar con `command-os-update`, `tests/escritorio.sh`,
  `tests/idioma.sh`, `tests/actualizaciones.sh`, la tienda) porque la CI no corre (facturación de
  GitHub); la CI la vuelve a probar en el PR. `tests/escritorio.sh` comprueba ahora que Bazaar y
  xarchiver enlazan con las bibliotecas de la fecha, para que una así no se valide.
- **Instalación del sistema (`/var/lib/flatpak`), no por cuenta:** los runtimes (cientos de MB) se
  descargan una vez para todas las cuentas. Polkit de serie de Flatpak: `wheel` instala sin contraseña
  en la sesión activa; el resto, con la de un administrador (no hace falta regla propia).
- **Las apps Flatpak entran en las instantáneas de `@`** (`/var/lib/flatpak`). Volver atrás las deja como
  estaban (repo y despliegue juntos, coherente) a cambio de instantáneas más grandes. Un subvolumen
  `@flatpak` toca el instalador: queda en `ROADMAP.md`.
- **`command-os-update` actualiza las apps al final, sin preguntar.** Pacman ya preguntó y las apps no
  tocan el sistema; si falla, lo de pacman queda hecho. El aviso de la barra aún no las cuenta (mirarlo
  sin tocar `/var/lib/flatpak` desde la unidad de solo lectura pide más trabajo): en `ROADMAP.md`.
- **Tema de las apps: copias de GTK, no enlaces.** Con el permiso global de leer
  `xdg-config/gtk-3.0/gtk.css` (y `settings.ini`, y los de `gtk-4.0`) las apps ven esos archivos, pero
  un enlace a `/usr/share/command-os` no lleva a nada dentro de su caja. La copia se pone al día con la
  de serie mientras su suma sea la de la última copia (como hace `ucf`); si no coincide con la de
  serie ni con esa suma, se trata como del usuario. **El permiso es por archivo, no de la carpeta:**
  `gtk-3.0` guarda también `bookmarks` (las carpetas marcadas en Thunar), que ninguna app tiene por qué
  ver. Descartado: dejar las apps sin la paleta de Command OS.
- **Un `.flatpakrepo` solo con `https://` y clave GPG**, y sin valores partidos en varias líneas:
  la ventana enseña lo que flatpak va a usar (Python y GLib leen distinto los valores de varias
  líneas) y un repositorio sin firma por http sería una puerta de entrada.
- **xarchiver, no file-roller:** GTK 3 como Thunar, así que coge `gtk-3.0/gtk.css` (file-roller es GTK 4
  y se vería distinto); `thunar-archive-plugin` lo usa para «extraer aquí». `unrar` (licencia propia,
  redistribuible, en `extra`) para los rar.
- **Tipos de archivo en `/usr/share/applications/mimeapps.list`** (el sitio de la distribución en la
  especificación; `/etc/xdg` queda para el administrador y `~/.config` para el usuario).
- **AppImage, `.deb`, `.rpm` y `.flatpakrepo` en una ventana propia** (`command-os-abrir-descarga`), no
  con xarchiver (los declara pero solo enseña sus tripas): un AppImage se abre tras avisar (y se marca
  como ejecutable, que es lo que nadie sabe hacer); un `.deb`/`.rpm` no se puede instalar en Arch sin
  romperlo, así que lleva a la tienda. Descartado: convertir paquetes (`debtap`) y Gear Lever para los
  AppImage (una app más para algo que se resuelve con un aviso).

## 2026-10-15 — Batería y aplicaciones fijadas en la barra (`docs/notas/escritorio.md`)

- **La barra sigue con el `battery` de Waybar en texto** (`bat 85%`), decisión del usuario: se llegó a
  hacer un módulo propio con iconos y el porcentaje ocultable, y lo descartó (le gusta el texto). Lo
  nuevo (avisos y límite de carga) va aparte y no toca la barra.
- **Avisos al 20 % (normal) y al 10 % (urgente)**, decisión del usuario (mantener la batería entre el
  20 y el 80 %). Cada umbral avisa una vez por descarga.
- **Límite de carga al 80 % solo si el portátil lo permite** (`charge_control_end_threshold`), apagado
  de serie. El usuario prefería no hacerlo si no valía para todos; se hizo así porque quien no lo tiene
  no ve nada (como GNOME y KDE) y quien lo tiene alarga la vida de la batería. Sin límite guardado no se
  toca nada al arrancar: se respeta lo que haya puesto la BIOS. Descartado: TLP (un servicio más para
  una sola cosa) y el modo conservación de los IdeaPad (corta al ~60 %, no al 80 %).
- **Polkit deja cambiar el límite a la sesión activa sin contraseña**, como el límite de UPower en
  GNOME: solo cuida la batería y se deshace con el mismo interruptor. El ayudante solo acepta
  `limite 80`, `limite no` y `aplicar`.
- **Fijar aplicaciones con módulos propios** (`group/fijadas` por `include`, iconos en una hoja que
  importa la de la barra): `wlr/taskbar` no sabe fijar y su clic derecho no puede lanzar órdenes, así
  que **no se puede fijar desde la ventana abierta** (lo que pidió el usuario). Se fija con el clic
  derecho en el logo (el lanzador, pero fija en vez de abrir) y se quita o se mueve con el clic derecho
  en la propia fijada. Una fijada abierta sale además como ventana en la barra de tareas (no se juntan:
  sin IPC de labwc no se sabe a qué ventana corresponde). Descartado: cambiar de barra (sfwbar,
  nwg-panel) por esto, y `lswt`/`wlrctl` (no están en los repos de Arch).

## 2026-10-08 — Zona horaria y hora (`docs/cuentas.md` § «Hora»)

- **La zona se elige en el asistente de primer arranque** (decisión del usuario), como el idioma: la
  elige quien recibe el equipo y se aplica al crear la cuenta. Descartado: dejarla fija del
  instalador (quien instala fuera de España quedaba con la hora mal y solo se cambiaba en una terminal).
- **Un botón con buscador y no región → ciudad ni un mapa.** Casi todo el mundo busca su país, no
  su ciudad, y no sabe que Canarias está en «Atlántico»; un mapa no cabe en 720 px ni se usa bien con
  teclado. Se busca por comienzo de palabra (si no, «utc» encuentra «Dutch»).
- **Países traducidos con `iso-codes`; ciudades tal cual, en inglés.** Traducir ~400 ciudades en
  `os/po/` sería mucho texto que nadie revisa; buscar el país en tu idioma ya encuentra tu zona.
- **Sin red, la zona propuesta es la del instalador, y un teclado de un país con una sola zona propone
  la suya** (solo si no se ha elegido otra a mano). Descartado: deducirla del idioma (el inglés no dice
  el país), geolocalizar por IP (necesita red y saca la ubicación del equipo) y sugerir con `us`,
  `latam` o `br` (países con varias zonas: adivinar sería peor que no proponer).
- **Una sola orden cambia la zona (`command-os-zona-horaria`)**, la del asistente y la de las
  personas, igual que `command-os-idioma`.
- **Dual boot: el reloj del equipo sigue en hora local (`LOCAL`) y manda el reloj que es fiable.** Sin
  hora de la red, el reloj del equipo (Windows lo deja en la hora de pared) se vuelve a leer con la
  zona nueva; con ella, se reescribe el del equipo. Descartado: `timedatectl set-timezone` siempre
  (escribe en el reloj del equipo la hora del sistema, que en el primer arranque se calculó con la zona
  del instalador: dejaría la hora mal también en Windows) y pasar Windows a UTC (`RealTimeIsUniversal`
  toca el registro de Windows, fuera de lo que hace el instalador).
- **Hora por la red (`systemd-timesyncd`) de serie, activada una sola vez.** Sin ella, un reloj que va
  mal no se corrige nunca. Es poco tráfico, así que también se usa con datos medidos.

## 2026-10-10 — Paneles del escritorio: actualizaciones, cuentas y disco cifrado

- **El panel de actualizaciones solo informa y lanza; no instala.** Enseña lo pendiente y abre
  `command-os-update` en una terminal, como antes. Instalar desde el panel exigiría resolver a ciegas
  las preguntas de pacman (conflictos, sustituciones) y, si sale mal, el equipo queda a medias.
  Descartado: instalar con `--noconfirm` desde un botón. Gana lo que se ve (versiones, paquetes, cuándo
  se comprobó) sin cambiar quién decide.
- **Todo lo que necesita root va a un ayudante pequeño lanzado con `pkexec`, y el panel nunca ve la
  contraseña del administrador.** Había ya un agente de polkit en la sesión (`polkit-gnome`), así que
  la autenticación es la del sistema y el panel no maneja la contraseña de nadie. Cada ayudante
  (`gestionar-cuentas`, `gestionar-disco`) valida todo lo que recibe, recibe las contraseñas por la
  entrada estándar (nunca como argumento) y contesta con códigos de error que el panel traduce. Cada
  uno tiene su propia acción de polkit que solo deja lanzar ese programa, y **la contraseña de
  administrador se pide cada vez** (nada de `auth_admin_keep`): el ayudante de cuentas puede crear
  administradoras, y con la autenticación recordada cualquier proceso de la sesión podría usar esos
  minutos para llegar a root (revisión de seguridad). Descartado: `sudo -S` con una
  contraseña de administrador escrita en el panel (el panel la vería y habría que dársela a sudo por una
  tubería) y un demonio propio (más superficie y un proceso residente).
- **La contraseña propia se cambia sin root**, con `passwd` en un pseudoterminal: PAM comprueba la
  actual y no hace falta ayudante. Descartado: un ayudante de root que verifique la actual (un camino
  más con privilegios para algo que el sistema ya sabe hacer).
- **Cuentas nuevas: normales de serie; el permiso de administrar se da aparte.** Y límites duros en el
  ayudante, no solo en la pantalla: no se borra ni se quita el permiso a quien lo pide, no se borra una
  cuenta con la sesión abierta y siempre queda una administradora. Si se borra la cuenta principal o la
  de inicio automático, el equipo pasa a la primera administradora.
- **Borrar una cuenta pregunta si se conserva su carpeta personal.** Por defecto se borra; el interruptor
  la conserva, pero **pasa a root con modo 700**: sus archivos seguirían con el UID de la cuenta borrada
  y una cuenta nueva puede recibir ese mismo UID (heredaría los datos; lo señaló la revisión de
  seguridad). Descartado: conservarla con su dueño (esa herencia), conservarla siempre (se llena el
  disco de carpetas de cuentas que ya no existen) y borrarla sin preguntar (no se puede deshacer).
- **El idioma de una cuenta es `~/.config/locale.conf`** y `lib/entorno-grafico` lo lee después del del
  equipo. Se escribe como la propia cuenta (`runuser`), no como root, para que un enlace simbólico en su
  carpeta no pueda desviar la escritura (probado en `tests/cuentas.sh`). Si el locale no está generado,
  un ayudante de root lo genera (`command-os-idioma generar`).
- **La zona horaria se cambia desde el panel de cuentas, pero sigue siendo del equipo**: pide la
  contraseña de un administrador y el selector es el mismo del asistente (`lib/selector_zona.py`),
  extraído para no duplicarlo.
- **Disco cifrado: el panel genera la clave de recuperación, la enseña una vez y no cambia nada hasta
  que se comprueban dos grupos.** Misma garantía que el instalador (se ha apuntado antes de que valga).
  El ayudante añade la clave nueva en una ranura libre, comprueba que abre y solo entonces quita la
  vieja: el disco nunca se queda sin clave de recuperación. La contraseña actual tiene que abrir la
  ranura 0 (si fuera la de recuperación, cambiarla sustituiría la ranura equivocada), y con más de dos
  claves no se toca nada (quien las puso a mano usa `cryptsetup`). Descartado: generar la clave en el
  ayudante y devolverla por pantalla (el cambio ya estaría hecho sin saber si se apuntó).

## 2026-10-10 — Una sola contraseña con el disco cifrado (`docs/cifrado.md`)

- **El asistente propone «entrar sin contraseña al encender» activado si el disco está cifrado.** Con
  el cifrado ya se teclea una contraseña en el splash; pedir otra al instante es fricción que lleva a
  contraseñas flojas o a desactivar el cifrado. La cuenta sigue protegida donde importa: la pantalla se
  bloquea con su contraseña y, sin la del disco, no se pasa del splash. Es una propuesta, no una
  imposición (se apaga en el mismo asistente o después con `command-os-login pedir`). Descartado: dejarlo
  apagado con un aviso (casi nadie lo cambiaría) y forzarlo sin interruptor (un equipo compartido con el
  disco ya abierto no debe dejar entrar a cualquiera).
- **Se detecta por `cryptdevice=` en `/proc/cmdline`**, que ponen el instalador de PC y
  `command-os-rollback`; no por un archivo de estado aparte que podría desparejarse del disco real.

## 2026-10-07 — Cifrado del disco (`docs/cifrado.md`)

- **Opcional y marcado por defecto, en disco entero y en dual boot.** En un portátil con Windows
  cifrado por BitLocker, un Linux sin cifrar al lado sería el punto débil. La imagen USB
  (`build-image.sh`) no se cifra: es genérica y no hay a quién pedirle la contraseña. Descartado:
  siempre cifrado (hay equipos donde no se quiere, como un banco de pruebas) y desmarcado por defecto
  (casi nadie lo marcaría).
- **`/boot` en una partición aparte sin cifrar; GRUB no descifra nada.** Así la contraseña se pide una
  sola vez y dentro del splash. Descartado: `/boot` cifrado con `GRUB_ENABLE_CRYPTODISK` (GRUB la pide
  antes del splash en modo texto, tarda con argon2id y hay que pedirla dos veces o meter una clave en el
  initramfs). Coste aceptado: el kernel sale de las instantáneas; `command-os-rollback` pone el de la
  instantánea y rehace su initramfs.
- **Clave de recuperación que guarda el usuario**, en una segunda ranura de LUKS: generada en el
  equipo, enseñada una vez y comprobada con dos grupos al azar; nadie más tiene copia. No es una puerta
  trasera (esa sería una forma de entrar del fabricante): es como la de BitLocker, pero sin copia en
  ningún servidor. Solo cifras, para teclearla en cualquier distribución de teclado; se acepta con o
  sin guiones. Descartado: nada (un olvido = perderlo todo) y guardarla en el equipo o en la nube.
- **Gancho propio del initramfs (`command-os-cifrado`) antes de `encrypt`.** El de Arch pide en inglés
  y, tras 3 fallos, deja una consola de emergencia. El propio pide en castellano dentro del splash,
  sin límite de intentos, y `encrypt` lo respeta («Device already exists»). Descartado: copiar y
  modificar `encrypt` (habría que seguirle los cambios) y pasar al initramfs de systemd (`sd-encrypt`),
  que rompe el arranque de instantáneas (`grub-btrfs-overlayfs` solo va en el de udev).
- **LUKS2 con argon2id y TRIM (`allow-discards`) guardado en la cabecera.** TRIM alarga la vida del
  SSD y mantiene su rendimiento; a cambio se ve qué zonas están libres, no lo que contienen.
- **Contraseña de 8 caracteres como mínimo, sin ñ ni tildes.** Igual que las cuentas; argon2id frena
  la fuerza bruta. Sin ñ ni tildes porque se teclea antes de que arranque el sistema: si el teclado no
  las diera, no se podría entrar.
- **Todo se pregunta antes de la confirmación del borrado**: después no hay más preguntas y, si se
  cancela, no se ha tocado nada.

## 2026-10-07 — Instalador publicado y firmado (`docs/instalacion.md` § 2)

- **Publicar el instalador** (decisión del usuario) en `command-os-versions`, junto al paquete. No
  revela nada nuevo: el árbol `os/` ya va dentro del paquete público y los scripts no tienen
  secretos. Quita el token de GitHub del USB, que da acceso al repositorio privado si se pierde.
  Descartado: seguir clonando con token y una ISO propia (más trabajo y otra cosa que mantener).
- **Firmado con la clave del paquete, y comprobado antes de ejecutar nada.** `instalar-command-os.sh`
  lleva la huella escrita y usa un anillo de claves vacío: una clave o una firma sustituidas no
  valen. Lo primero que se descarga (ese script) depende de HTTPS, como cualquier instalador por
  internet; para comprobarlo a mano está su `.sig`.
- **El equipo instala el paquete firmado del repositorio**, no uno construido al instalar: lo
  instalado es exactamente lo publicado y el primer aviso de actualizaciones no ve una versión «nueva»
  que no lo es. Desde un clon del repositorio se sigue construyendo (desarrollo).
- **El paquete solo se republica si cambia `os/`:** un cambio del instalador no avisa a todos los
  equipos de una actualización que no cambia nada.

## 2026-10-07 — Idioma del sistema (`docs/idioma.md`)

- **Castellano de serie y elección de idioma en el asistente de primer arranque** (decisión del
  usuario). El producto habla en castellano; con `en_US` el menú de GRUB y los programas sin
  traducción propia salían en inglés. Elegirlo en el asistente deja usar el equipo en otro idioma sin
  reinstalar. Descartado: solo castellano fijo (cierra la puerta a otros idiomas) y dejarlo en `en_US`.
- **gettext para las traducciones, con el castellano como texto original.** Es el estándar de Linux:
  sirve igual en Python y en bash, las herramientas avisan de lo que falta y cualquier traductor sabe
  usar un `.po`. Descartado: un diccionario propio en Python (no vale para los scripts y habría que
  tirarlo al traducir el resto) y textos originales en inglés (el producto se escribe en castellano).
- **Una sola orden cambia el idioma (`command-os-idioma`)**, que usan el asistente y las personas. Así
  el locale generado, `locale.conf` y el menú de GRUB nunca quedan desparejados.
- **El idioma se aplica al crear la cuenta, no al elegirlo.** El asistente cambia al momento, pero el
  sistema no se toca hasta el final: si se apaga a medias, no queda nada cambiado.
- **Idioma por equipo, no por cuenta.** GRUB, el splash y la pantalla de inicio de sesión son del
  equipo, y hoy hay una sola cuenta. Si se añaden cuentas desde el escritorio, se podrá dar a cada una
  el suyo (`~/.config/locale.conf`). *(Hecho el 2026-10-10 con el panel de cuentas: ver «Paneles del
  escritorio». El equipo sigue teniendo uno y cada cuenta puede tener el suyo encima.)*
- **El idioma no cambia el teclado.** Quien elige inglés en España sigue con teclado español; el
  teclado tiene su propia fila.
- **Las ventanas leen `/etc/locale.conf` al abrirse** (`entorno-grafico`): systemd solo lo lee al
  arrancar y el cambio no llegaría a la pantalla de inicio de sesión hasta reiniciar.
- **En este paso se traducen el asistente, la pantalla de inicio de sesión, `crear-cuenta` y el tema de
  GRUB**: lo que se ve al elegir el idioma. El resto de textos propios (barra, menús, splash,
  instalador) va como punto propio del roadmap. (Barra y menús ya están: ver «El escritorio en inglés».)

## 2026-10-07 — El escritorio en inglés (`docs/idioma.md`)

- **Los archivos estáticos se traducen al abrir la sesión, no se duplican por idioma.** Waybar (JSON),
  hyprlock y el menú de labwc no pueden llamar a gettext. Se marcan sus textos (`{{texto}}`, o el
  propio `label="…"` del menú) y `lib/traducir.py` los traduce con el mismo catálogo que el resto.
  Descartado: un archivo por idioma (se desincronizan al cambiar uno) y un diccionario aparte.
- **El menú de labwc deja de estar en `/etc/xdg/labwc` y va en `/usr/share/command-os/config/labwc/`**,
  traducido en `$XDG_RUNTIME_DIR` al iniciar sesión. Con `--merge-config`, labwc lee primero el del
  sistema y se queda con el primero de cada id (el de la cuenta llega tarde y se ignora, con un aviso
  «already exists»): una copia traducida en `~/.config` no se vería. Se probó. Descartado: pipemenus
  (no valen para el menú raíz) y copiar el menú a `~/.config` (no gana al del sistema).
- **`t` y `tn` en un `lib/textos.sh` común** (bash y sh) y no una función por script; `tn` para
  singular y plural. `build/po.sh` busca las llamadas con su propio extractor: `xgettext -L Shell`
  se pierde los textos tras `{`, `do` y `(( ))`. Falla si un texto no va entero y literal.
- **Los registros y diagnósticos de administración siguen en castellano** (`logger`, avisos de
  `apply-*`, uso de las órdenes internas): los lee quien administra, y mezclar idiomas en el diario
  dificulta buscar. Se traducen lo que ve la persona: avisos, paneles, menús y las órdenes de terminal.
- **Las órdenes de terminal hablan el idioma de la sesión, no el del sistema que se acaba de elegir**
  (`LANG` de quien las lanza; sudo lo conserva). La confirmación de `command-os-rollback` es una palabra
  traducida (`SI`/`YES`) que se enseña en el mismo aviso: no se acepta la de otro idioma, para que lo
  que se pide y lo que se compara no puedan desparejarse. El `motd` queda sin traducir: no se muestra.
- **El idioma del splash va en la línea del kernel (`command-os.idioma=`), no en el initramfs.** El
  gancho del disco cifrado lo lee de `/proc/cmdline` y pide la contraseña en ese idioma; el tema lleva
  las imágenes de todos los idiomas y elige por el texto que recibe. Cambiar de idioma solo rehace el
  menú de GRUB, que `command-os-idioma` ya rehacía. Va en `GRUB_CMDLINE_LINUX` (como `cryptdevice=`)
  para que también lo lleven las entradas de recuperación y de instantáneas. Descartado: copiar la
  imagen del idioma al tema y rehacer el initramfs (sobrescribe archivos del paquete y tarda decenas
  de segundos en cada cambio, también en el asistente) y que Plymouth lo averigüe (su lenguaje no
  lee archivos ni la línea del kernel). Las imágenes salen de `os/po/` con
  `build/make-plymouth-textos.py`, así `tests/idioma.sh` también vigila esas traducciones.
- **El instalador también se traduce, y el idioma se pregunta antes que nada** (en el script del
  USB, antes de descargar). Es lo primero que ve quien instala y decide el idioma del sistema. El
  catálogo sale de `os/po/` del árbol firmado que se descarga (no se añade nada al paquete) y se
  compila en el USB; como el USB solo trae `C.UTF-8`, se genera el locale con `localedef`. Descartado:
  deducirlo del locale del USB (siempre es `C.UTF-8`) y un diccionario propio en bash (dos sistemas de
  traducción). Las palabras de confirmación del borrado son las del idioma elegido y solo esas: aceptar
  las de los dos idiomas relajaría la confirmación. Al elegir inglés, el teclado de serie es `us`.
- **Las capturas pasan de un `sh -c` incrustado en `rc.xml` a `command-os-captura`**, para poder
  traducir el aviso (y porque el XML escapado era ilegible).

## 2026-10-07 — Pantallas 16:9 y 16:10 y alta densidad (`docs/notas/pantallas.md`)

- **Escala automática fraccionaria (pasos de 0,25)**, por la densidad del monitor y con tope de
  720 px de alto útil. Es lo que se ve del tamaño justo en portátiles de 13–16". Coste aceptado: las
  apps antiguas por XWayland se ven algo borrosas a escala no entera. Descartado: solo 1 o 2 (muchos
  portátiles quedan demasiado grandes o pequeños) y escala 1 fija con wdisplays (no se guarda ni
  llega al inicio de sesión).
- **Referencia 120 ppp en paneles internos y 110 en monitores**: los internos se miran más de cerca.
  Con estos valores salen las escalas habituales de cada tamaño (Windows y GNOME rondan lo mismo).
- **Un vigilante por sondeo (`wlr-randr` cada 2 s) en vez de kanshi**: kanshi necesita perfiles
  por monitor; aquí la escala sale sola. labwc no avisa de pantallas nuevas a un script.
- **Fondos en 16:9 y 16:10 en vez de uno con margen de seguridad**: cada pantalla ve la composición
  entera y nítida. Pesa poco (~2,7 MB más). Descartado: un único 16:10 (en 16:9 recortaría arriba y abajo).
- **hyprlock con la configuración escalada al bloquear**: hyprlock ignora la escala de labwc. Solo la
  de serie; la de una cuenta se respeta tal cual.
- **Tema de GRUB generado al instalar para la pantalla del equipo**: GRUB no escala fuentes ni
  imágenes. Descartado: forzar GRUB a 1920x1080 (borroso y deformado en 16:10) y un tema fijo.
- **Splash en proporción al alto de la pantalla**, con fotogramas a doble resolución.

## 2026-10-07 — Prioridad x86

- **Se trabaja y se prueba en x86; nada específico de hardware ARM por ahora.** No se sabe qué placa
  ARM llevará el cyberdeck (la Raspberry Pi 5 era una suposición). Command OS sigue siendo para las dos
  arquitecturas (paquete `any`), pero la imagen ARM, el arranque de la placa y las pruebas en ARM se
  aparcan hasta tener el hardware. Descartado: seguir con la Pi 5 a ciegas (trabajo que puede no
  servir con otra placa).

## 2026-10-07 — Entrada al equipo (`docs/cuentas.md`)

- **Asistente de primer arranque, no pregunta al instalar.** La misma imagen vale para cualquier
  equipo y la cuenta la elige quien lo recibe. Descartado: preguntar en el instalador (la cuenta la
  pondría quien prepara el equipo).
- **Pedir contraseña de serie; inicio automático opcional.** Command OS también se instala en PCs
  (portátiles, equipos compartidos, dual boot). Las variantes de dispositivo (cyberdeck) proponen el
  inicio automático en el asistente. Descartado: inicio automático siempre (inseguro en un PC) y
  nunca (rompe el arranque limpio del cyberdeck).
- **Primera cuenta administradora, root bloqueado.** Sin administrador el equipo no se mantiene;
  `sudo` deja registro. Las cuentas que se añadan después serán normales de serie.
- **Greeter propio (GTK 4 en cage) en vez de ReGreet.** ReGreet 0.5 no tiene traducciones (textos
  fijos en inglés) y su panel no sigue la marca. Descartados también tuigreet (texto, no sigue la
  marca) y GDM/SDDM (pesados, arrastran otro escritorio).
- **Contraseña mínima de 8 caracteres.**
- **Sin recuperación de contraseña propia:** otra cuenta administradora o un USB de rescate. Una
  puerta trasera sería un agujero.

## 2026-10-07 — Instalar como sistema principal (`docs/instalacion.md`)

- **Dos formas de instalar en un PC: junto a Windows o como sistema principal**, con un asistente
  común (`build/x86/instalar.sh`) y un script por modo. La imagen USB (`build-image.sh`) se queda para
  probar sin instalar. Descartado: un único script con opciones (el modo que borra quedaría a un
  parámetro de distancia del que no borra).
- **Seguridad antes que comodidad en el borrado:** disco siempre indicado a mano, sin valor por
  defecto; se rechazan el USB en vivo, el sistema en marcha, discos montados, con swap o volúmenes en
  uso, particiones, solo lectura y < 30 GB; la confirmación es escribir el nombre exacto del disco (y
  `BORRAR WINDOWS` si lo hay). Solo corre desde el USB en vivo de Arch: no se puede lanzar por error
  en un equipo instalado. Descartado: confirmar con «SI» (se teclea sin leer) y elegir el disco más
  grande solo (puede ser el de los datos).
- **GPT con EFI de 1 GiB y btrfs para el resto, sin swap.** Igual que el dual boot y la imagen (mismas
  instantáneas y `command-os-rollback`). 1 GiB deja sitio a varios kernels si algún día van a la EFI.
- **GRUB con entrada en la NVRAM y además `EFI/BOOT/BOOTX64.EFI`:** hay firmwares que pierden u
  ordenan mal las entradas; la copia de reserva arranca igual. En el dual boot no se pone (es el
  arranque de reserva de Windows).
- **Lo común del dual boot y el disco entero en `build/x86/lib.sh`** (`install_base`,
  `configure_system`); `build-image.sh` se queda aparte porque hace una imagen genérica (zona UTC,
  cuenta de desarrollo, sin NVRAM).
- **Antes de `grub-install`, se borran las entradas `command-os` viejas de la NVRAM**
  (`forget_nvram_entries`): GRUB no actualiza una entrada con su misma ruta aunque apunte a otra
  partición, y al reinstalar la BIOS seguiría una entrada muerta (en dual boot, arrancaría Windows sin menú).
- **Menú de GRUB sin las entradas «EFI BootNext»** (`GRUB_DISABLE_BOOTNEXT=true`, `os/lib/apply-boot`):
  GRUB 2.16 copia en el menú la NVRAM del momento (USB, discos sueltos, Windows repetido).
- **Sin cifrado de disco en este paso:** pide la contraseña antes del splash y toca el initramfs y
  grub-btrfs; va como punto propio del roadmap (hecho después: «Cifrado del disco», arriba).

## 2026-10-07 — Aviso de actualizaciones (`docs/actualizaciones.md` § 7)

- **Comprobar a los 10 min de arrancar y cada 6 h, con retraso al azar.** Las versiones salen pocas
  veces al día; con muchos equipos, el azar evita que pregunten todos a la vez. Descartado: una vez al
  día (un equipo que se enciende un rato corto tarda en enterarse) y cada hora (más tráfico sin ganar nada).
- **Una comprobación por equipo, no por cuenta:** temporizador del sistema que escribe un archivo que lee
  la barra. Descartado: un servicio de usuario por cuenta (duplica descargas, no corre sin sesión y
  depende del entorno gráfico).
- **`checkupdates` (copia de la base de datos de pacman), nunca `pacman -Sy`:** sincronizar la real sin
  actualizar deja el equipo con bases de datos mezcladas (la causa clásica de roturas en Arch).
- **No se comprueba con datos medidos** (solo en automático); a mano, siempre. Un cyberdeck puede
  compartir los datos del móvil.
- **Notificación solo por versión nueva de command-os, una vez, con clic = actualizar.** Los paquetes de
  Arch sueltos solo salen en la barra (con Arch del día cambian a diario). Descartado: notificación crítica
  (se queda fija y es para fallos) y repetirla cada vez que se comprueba.
- **Actualizar abre `command-os-update` en una terminal, no un panel propio.** Se ve qué cambia, `sudo` y
  pacman piden confirmación y el resultado queda a la vista. Un panel gráfico necesitaría un agente de
  polkit para instalar y resolver a ciegas las preguntas de pacman (conflictos, sustituciones): si sale
  mal, el equipo queda a medias. Se retomará si hace falta.
- **Polkit deja lanzar la comprobación manual (solo ella, `start`) a la sesión local activa:** un clic
  derecho no debe pedir contraseña por mirar. Instalar sigue exigiendo `sudo`.
- **Si pacman cambia algo después de la comprobación, la barra la ignora** hasta la siguiente (y el gancho
  de pacman la repite al terminar): nunca enseña un aviso de algo ya instalado.

## 2026-10-07 — Volver atrás (`command-os-rollback`)

- **El sistema recuperado usa el `/boot/grub` del anterior.** Descartado: regenerar la lista en el
  primer arranque (no arregla los módulos que no casan con la partición EFI ni las instantáneas de la
  imagen, que no tienen `/boot/grub`).

## 2026-10-07 — Clave de firma

- **Clave nueva al perder la anterior**, sin transición firmada: aún no se había publicado ningún
  paquete, así que ningún equipo confiaba en la antigua.
