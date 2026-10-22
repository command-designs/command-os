# Idioma del sistema y traducciones

Command OS habla en castellano de serie y se puede usar en inglés. Léelo antes de tocar el idioma, el
asistente de primer arranque o cualquier texto que se traduzca.

## Para quien usa el equipo

- **Castellano de serie.** El instalador y la imagen USB dejan `LANG=es_ES.UTF-8`, con `es_ES` y
  `en_US` ya generados.
- **Se elige en el primer arranque.** La primera fila del asistente es el idioma (castellano por
  defecto, inglés): la ventana cambia al momento y el idioma se aplica al crear la cuenta, junto con el
  menú de arranque. Hasta entonces no se toca nada del sistema.
- **Cambiarlo después:** `command-os-idioma en` (o `es`) en una terminal; sin argumentos dice el
  actual y `command-os-idioma lista` enseña los que hay. La pantalla de inicio de sesión sale ya en el
  idioma nuevo al cerrar sesión; el resto del sistema, al reiniciar.
- **Qué cambia:** el asistente, la pantalla de inicio de sesión, el menú y el tema de GRUB, los
  mensajes de `crear-cuenta`, **el escritorio entero** (barra y su aviso de actualizaciones, menús de
  labwc, paneles «atajos», «acerca de» y energía, fondos, pantalla de bloqueo, notificaciones de
  capturas, escritorios y bloqueo fallido), **las órdenes de terminal** (`command-os-update`,
  `-rollback`, `-login`, `-idioma`: sus mensajes salen en el idioma de la sesión que las lanza), **la
  contraseña del disco cifrado en el splash** y los programas que traen su propia traducción (GTK,
  Firefox…). También **el instalador** (`instalar-command-os.sh` y `build/x86/`): pregunta el idioma
  antes que nada e instala el sistema en ese idioma. Siguen en castellano el `motd` (no se ve: las cuentas llevan
  `.hushlogin`) y los registros y diagnósticos de administración (`logger`, avisos de `apply-*`, uso de
  las órdenes internas).
- **Confirmar un `command-os-rollback`:** se escribe la palabra que dice el aviso: `SI` en castellano,
  `YES` en inglés.
- **Cuándo se nota:** barra, menús y bloqueo leen el idioma al abrir la sesión: tras
  `command-os-idioma en`, al cerrar sesión y volver a entrar (o reiniciar).
- El teclado es aparte: elegir inglés no cambia la distribución del teclado.

## Cómo funciona

| Pieza | Qué hace |
| --- | --- |
| `command-os-idioma` | La única forma de cambiar el idioma. Lista de idiomas, genera el locale si falta (`/etc/locale.gen` + `locale-gen`), cambia `LANG` en `/etc/locale.conf` (conserva el resto; nunca lo deja a medias) y ejecuta `apply-boot`. |
| `lib/crear-cuenta --idioma` | El asistente pasa el idioma elegido; se aplica después de crear la cuenta y, si falla, la cuenta se deshace. |
| `lib/entorno-grafico` | Lee `LANG` y `LC_*` de `/etc/locale.conf` al abrir cada pantalla (asistente, inicio de sesión, sesión) y, después, de `~/.config/locale.conf` si la cuenta tiene idioma propio (gana al del equipo). systemd solo lo lee al arrancar. |
| `lib/apply-boot` | Genera el menú de GRUB con el `LANG` del sistema («Opciones avanzadas…») y los textos del tema (cuenta atrás y ayuda de teclas) traducidos, y pone `command-os.idioma=es\|en` en `GRUB_CMDLINE_LINUX` (la Pi, aparcada, no lo lleva: sale en castellano). |
| `initcpio/hooks/command-os-cifrado` | Lee `command-os.idioma=` de la línea del kernel (el initramfs no tiene `locale.conf` ni gettext) y pide la contraseña del disco en ese idioma; sin el parámetro, en castellano. Sus textos van escritos en cada idioma (`textos_cifrado`). |
| `branding/plymouth/command/{texto-clave*,diag-*,estado-*}.<idioma>.png` | Los textos del splash (la contraseña y las comprobaciones de arranque), como imágenes (la ñ y las tildes no se ven en el initramfs). Los genera `build/make-plymouth-textos.py` desde `os/po/`; `command.script` elige los de la contraseña por el texto que le manda el gancho y los de la lista por el idioma que llega con cada estado (`lib/diagnostico-arranque` lo lee de `command-os.idioma=`). |
| `os/po/<idioma>.po` | Las traducciones. El `PKGBUILD` las compila a `/usr/share/locale/<idioma>/LC_MESSAGES/command-os.mo`. |
| `lib/textos.sh` | `t` y `tn` para los scripts de shell (bash y sh). Se carga con `source`. |
| `lib/traducir.py` | Traductor sin GTK: `traductor()` para Python y dos modos para archivos de configuración que no pueden llamar a gettext: `plantilla` (los `{{textos}}`) y `etiquetas` (los `label="…"` de un menú XML). |
| `command-os-config` | Da la configuración de serie de Waybar traducida (copia en `$XDG_RUNTIME_DIR/command-os/config/`); si la cuenta tiene la suya, esa. Mismo mecanismo para hyprlock, que lo hace `command-os-lock`. |
| `lib/menus-labwc` | Deja el menú de labwc traducido en `$XDG_RUNTIME_DIR/command-os/xdg/labwc/menu.xml`; `command-os-session` pone esa carpeta la primera de `XDG_CONFIG_DIRS`. |

**Traducciones con gettext** (dominio `command-os`). El texto original es el castellano (el `msgid`):
sin traducción se ve el original. En Python, `_ = traductor()` de `lib/comun.py` (el asistente lo pide
para el idioma elegido, aún sin aplicar); en shell, `t` (y `tn` para singular y plural) de `lib/textos.sh`;
en los archivos de configuración, `{{texto}}` (Waybar, hyprlock) o la propia etiqueta `label="texto"`
(menús de labwc), que se traducen al abrir la sesión (tabla de arriba).

## Añadir o cambiar textos

1. En el código, el texto en castellano dentro de `_("…")` (Python), `t '…'` o `tn 'un %d' 'varios %d' N N`
   (shell, el texto entero y literal entre comillas) o `{{…}}` en Waybar/hyprlock; en un menú de labwc,
   solo el `label="…"`. Con datos variables, `{nombre}` en Python (`.format(nombre=…)`) y `%s`/`%d` en
   shell; nunca se traduce un texto montado a trozos. El singular de `tn` lleva también `%d`.
2. Si es un archivo nuevo con textos, añadirlo a `PYTHON`, `SHELL_`, `MARCAS` o `ETIQUETAS` en
   `build/po.sh`. `build/po.sh` falla si una llamada a `t` no lleva el texto escrito entero.
3. `bash build/po.sh` (necesita gettext; en WSL, Arch) pone al día `os/po/*.po`: los textos nuevos
   quedan vacíos y los cambiados, marcados `fuzzy`. Traducirlos y quitar la marca.
4. `tests/idioma.sh` (CI) falla si falta alguna traducción, hay alguna `fuzzy` o sobra algún texto.

## El instalador

Corre en el USB de Arch, que solo trae el locale `C.UTF-8` (con él gettext no traduce) y no tiene
Command OS. `instalar-command-os.sh` pregunta el idioma antes de descargar nada (sus pocos mensajes
van escritos en los dos idiomas, porque aún no tiene el catálogo) y lo pasa como `COMMAND_OS_IDIOMA`.
`cargar_idioma` (`build/x86/lib.sh`) genera el locale (`localedef`, un segundo), compila
`os/po/<idioma>.po` del mismo árbol (`msgfmt`) y deja `IDIOMA` (el `LANG` del sistema instalado) y el
teclado de serie (`us` en inglés) y la zona horaria de serie (`Europe/Madrid` en castellano, `UTC` en inglés;
`TIMEZONE` manda; el instalador no la pregunta, la elige el asistente de primer arranque). `configure_system` pasa ese catálogo a `os/install.sh`, que corre
dentro del sistema nuevo antes de que esté el paquete (`COMMAND_OS_LOCALE_DIR`). Las traducciones salen
siempre del árbol del instalador, nunca de un
Command OS instalado; en castellano no se traduce aunque el entorno esté en otro idioma. Las
confirmaciones que se teclean (`BORRAR WINDOWS`, `SI`) son las del idioma elegido, y solo esas
(`tests/discos.sh`).

## Añadir un idioma

1. Su línea en `IDIOMAS` de `os/bin/command-os-idioma` (locale y nombre en su idioma). El asistente
   saca la lista de ahí.
2. `os/po/<código>.po` (copiar `en.po`, cambiar `Language:` y traducir).
3. Generar su locale en los instaladores (`build/x86/lib.sh`, `build/x86/build-image.sh`) para que
   elegirlo en el asistente no tarde, y añadirlo a `elegir_idioma`/`cargar_idioma` (`build/x86/lib.sh`)
   y a la pregunta de `instalar-command-os.sh`. Si no, `command-os-idioma` lo genera al elegirlo (unos segundos).
4. Splash: `python build/make-plymouth-textos.py` (sus imágenes), los textos del idioma en
   `textos_cifrado` de `os/initcpio/hooks/command-os-cifrado`, con una palabra que `command.script`
   reconozca (`display_password_callback`), y cargar en `command.script` los textos de la lista en ese
   idioma (hoy, `nombre_es`/`nombre_en`…; sin eso salen en castellano). `tests/idioma.sh` comprueba las imágenes.

## Cómo se ha probado

- `tests/idioma.sh` y `tests/cuentas.sh` (CI, en cada cambio): traducciones completas, catálogo
  instalado, `command-os-idioma` (cambios, rechazos, locale que falta, comillas), tema de GRUB en los
  dos idiomas y `crear-cuenta --idioma`.
- VM `command-os-instalador` (2026-10-07), instalando en disco entero: `LANG=es_ES.UTF-8` y menú de
  GRUB en castellano. En el asistente: cambio a inglés al momento, cambio de teclado (reabre cage y
  sigue en inglés), errores en inglés y cuenta creada; después, pantalla de inicio de sesión en inglés
  (fecha, contraseña mala), escritorio con `LANG=en_US.UTF-8` y GRUB con `set lang=en_US`, «Advanced
  options» y el submenú de instantáneas traducido.
- Escritorio traducido (2026-10-07), VM `command-os-x86` con `command-os-idioma en`: menú del
  escritorio y atajos, «acerca de», bloqueo («session locked»), avisos de capturas y de escritorios,
  y la barra con su configuración traducida; sin avisos «already exists» de labwc. `tests/idioma.sh`
  comprueba Waybar (JSON válido), hyprlock, el menú (XML válido y mismo número de etiquetas),
  `lib/menus-labwc`, `t`/`tn` en los dos idiomas y el aviso de actualizaciones. Las órdenes de
  terminal, con `LANG` en cada idioma: errores y estado de `command-os-idioma`, modo de
  `command-os-login`, error de `command-os-rollback` (sin instantáneas) y su palabra de confirmación.
- Splash del disco cifrado (2026-10-07), VM `command-os-instalador` instalando en un disco temporal
  con cifrado: sin el parámetro, «contraseña del disco · o la clave de recuperación» y
  «desbloqueando el disco»; tras elegir inglés en el asistente, `command-os.idioma=en` en
  `GRUB_CMDLINE_LINUX` y, al reiniciar, «disk password · or the recovery key», «wrong password · type
  it again» con una mala, «unlocking the disk» y arranque hasta la pantalla de inicio de sesión.
- Instalador en inglés (2026-10-08), VM `command-os-instalador` en un disco temporal, disco entero con
  cifrado: todas las preguntas y mensajes en inglés (también los de `os/install.sh`), discos
  rechazados con el motivo traducido, `ERASE WINDOWS`/`YES` en `tests/discos.sh`; el sistema queda con
  `LANG=en_US.UTF-8`, teclado `us` y `command-os.idioma=en` junto a `cryptdevice=`, y al encender, el
  splash en inglés y el asistente ya en inglés con teclado «English (US)».
- Sin probar: verlo en un PC real (lo mismo que la VM salvo la pantalla).

**Decisiones** (con lo descartado, en `docs/decisiones/README.md`): gettext y no un diccionario propio;
castellano como texto original; idioma del equipo, con un idioma propio opcional por cuenta
(`~/.config/locale.conf`, que escribe el panel de cuentas, [`cuentas.md`](cuentas.md) § «El panel de
cuentas»; lo lee `lib/entorno-grafico` al abrir la sesión). GRUB, el splash y la pantalla de inicio de
sesión siguen siendo del equipo.
