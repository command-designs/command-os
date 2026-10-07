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
  mensajes de `crear-cuenta` y los programas que traen su propia traducción (GTK, Firefox…). El
  resto de textos propios de Command OS (barra, menús, «acerca de», splash, instalador) sigue en
  castellano hasta que se traduzca (`ROADMAP.md`).
- El teclado es aparte: elegir inglés no cambia la distribución del teclado.

## Cómo funciona

| Pieza | Qué hace |
| --- | --- |
| `command-os-idioma` | La única forma de cambiar el idioma. Lista de idiomas, genera el locale si falta (`/etc/locale.gen` + `locale-gen`), cambia `LANG` en `/etc/locale.conf` (conserva el resto; nunca lo deja a medias) y ejecuta `apply-boot`. |
| `lib/crear-cuenta --idioma` | El asistente pasa el idioma elegido; se aplica después de crear la cuenta y, si falla, la cuenta se deshace. |
| `lib/entorno-grafico` | Lee `LANG` y `LC_*` de `/etc/locale.conf` al abrir cada pantalla (asistente, inicio de sesión, sesión). systemd solo lo lee al arrancar. |
| `lib/apply-boot` | Genera el menú de GRUB con el `LANG` del sistema («Opciones avanzadas…») y los textos del tema (cuenta atrás y ayuda de teclas) traducidos. |
| `os/po/<idioma>.po` | Las traducciones. El `PKGBUILD` las compila a `/usr/share/locale/<idioma>/LC_MESSAGES/command-os.mo`. |

**Traducciones con gettext** (dominio `command-os`). El texto original es el castellano (el `msgid`):
sin traducción se ve el original. En Python, `_ = traductor()` de `lib/comun.py` (el asistente lo pide
para el idioma elegido, aún sin aplicar); en bash, una función `t` que llama a `gettext` (ver
`lib/crear-cuenta`).

## Añadir o cambiar textos

1. En el código, el texto en castellano dentro de `_("…")` (Python) o `t '…'` (bash). Con datos
   variables, `{nombre}` en Python (`.format(nombre=…)`) y `%s` en bash; nunca se traduce un texto
   montado a trozos.
2. Si es un archivo nuevo con textos, añadirlo a `PYTHON` o `SHELL_` en `build/po.sh`.
3. `bash build/po.sh` (necesita gettext; en WSL, Arch) pone al día `os/po/*.po`: los textos nuevos
   quedan vacíos y los cambiados, marcados `fuzzy`. Traducirlos y quitar la marca.
4. `tests/idioma.sh` (CI) falla si falta alguna traducción, hay alguna `fuzzy` o sobra algún texto.

## Añadir un idioma

1. Su línea en `IDIOMAS` de `os/bin/command-os-idioma` (locale y nombre en su idioma). El asistente
   saca la lista de ahí.
2. `os/po/<código>.po` (copiar `en.po`, cambiar `Language:` y traducir).
3. Generar su locale en los instaladores (`build/x86/lib.sh`, `build/x86/build-image.sh`) para que
   elegirlo en el asistente no tarde. Si no, `command-os-idioma` lo genera al elegirlo (unos segundos).

**Decisiones** (con lo descartado, en `docs/decisiones.md`): gettext y no un diccionario propio;
castellano como texto original; idioma por equipo, no por cuenta.
