# Command OS

Distro propia para el cyberdeck, construida como una capa de curación
(compositor, theming, apps por defecto, instalador) sobre una base ya
mantenida por terceros — Arch Linux ARM en el hardware real (Raspberry Pi 5),
Arch Linux x86_64 en la VM de desarrollo. No reinventamos kernel ni
infraestructura de paquetes: usamos pacman tal cual.

## Objetivo y por qué esta base

La meta original era **CachyOS + Omarchy corriendo en ARM** (Raspberry Pi 5).
Ninguno de los dos existe para aarch64: CachyOS solo publica x86_64 (su valor
son los repos y el kernel optimizados para x86-64-v3/v4) y Omarchy se instala
sobre Arch x86_64. Por eso la decisión fue **Arch Linux ARM con una capa curada
propia**: misma idea que Omarchy (instalador + paquetes + dotfiles) sobre Arch,
pero reconstruida por nosotros y arquitectura-agnóstica.

**Escritorio: labwc** (desde el 2026-10-05; antes Hyprland, último estado en la etiqueta
`hyprland-final`). Es un producto para clientes: ventanas flotantes con barra de título y botones,
barra de tareas, Alt+Tab, menú con clic derecho y Super para abrir aplicaciones, que cualquiera
entiende sin explicación; y es ligero (sin animaciones de ventanas ni efectos caros), que en un
Raspberry Pi 5 importa. Es el mismo compositor que usa Raspberry Pi OS por defecto.

**Estado respecto a esa meta**: `os/` ya tiene escritorio labwc con tema de ventanas propio,
tema de marca, notificaciones (Mako), bloqueo/idle (Hyprlock/Hypridle), OSD, splash de arranque,
atajos con su ayuda (Super+F1) y apps por defecto, verificado en una VM x86_64. Falta probar varias piezas,
empaquetarlo y llevarlo al Pi real: ver "Siguientes pasos" más abajo.

## Estructura

- `os/` — el producto: lista de paquetes (`packages.txt`), instalador
  (`install.sh`) y dotfiles (`dotfiles/`) para labwc/Waybar/Wofi/terminal. El tema de
  ventanas de labwc (`Command`) está en `branding/labwc/`.
  Esto es lo que se instala tanto en la VM de pruebas como, más adelante, en
  el Pi real.
- `build/packer/` — pipeline de build desatendido para la VM de desarrollo
  (QEMU, x86_64). Particiona disco, instala Arch base y corre
  `os/install.sh` sin intervención manual.
- `build/x86/` — imagen para USB (`build-image.sh`) e instalador en dual boot junto a Windows
  (`install-dualboot.sh`, guía en [`docs/dualboot.md`](docs/dualboot.md)).
- `build/iso/` — ISOs descargadas (no versionadas, ver `.gitignore`).

## Flujo de desarrollo (VM x86_64 en QEMU)

Ver `docs/testing.md` para el ciclo completo de build → iteración, y por qué
se usa QEMU en vez de VirtualBox.

Esta VM valida que `os/install.sh` instala todo sin errores (paquetes,
dotfiles, servicios) — es el ciclo rápido para iterar cambios. La
fluidez real del escritorio se juzga en el Raspberry Pi 5 físico o en bare metal: en la VM el
render es por software (ver `docs/testing.md`).

## Identidad y estado del tema

El escritorio sigue la marca de Command (`BRAND.md` de `command-web`): casi monocromo, rojo solo como
señal. Detalle y estado de cada ancla de marca en [`docs/DISENO.md`](docs/DISENO.md). Los assets están
en `os/branding/` (logo, fuentes, wallpaper, splash de arranque).

## Siguientes pasos

Por orden de prioridad:

1. **Probar lo configurado pero no verificado** en la VM: inactividad (bloqueo a los 5 min, pantalla
   apagada a los 10), portapapeles, teclas de volumen/brillo y el clic derecho en el escritorio
   (no se puede simular sin ratón virtual). Ya verificados con labwc: ventanas, Alt+Tab, menús,
   lanzador, ayuda de atajos, mezclador, bloqueo, notificaciones y espacios de trabajo.
2. **Cerrar la firma de arranque** (`BRAND.md` § 12, ancla 2): que el splash se pueda saltar con una
   tecla y medir la duración real de la animación.
3. **Pantalla de información del sistema** con nombre y código `CMD-OS` (ancla 5), visible desde el
   escritorio.
4. **Paquete pacman `command-os`** (`PKGBUILD`): dotfiles en `/etc/skel`, assets en
   `/usr/share/command-os`, `os-release` y temas. Sustituye al `cp -r` de `install.sh`, que hoy borra
   la config del usuario en cada ejecución. Después, repo propio para actualizaciones.
5. **Instalador pulido**: pedir usuario, contraseña y nombre del equipo (hoy `deck`/`deck` fijo),
   detectar variante de hardware (NVIDIA, VM, Pi) y no pisar config existente.
6. **Bare metal en x86**: grabar `command-os-x86.img` en un USB y probar con la GPU NVIDIA real
   (pendiente de tener el USB; ver `CLAUDE.md`).
7. **Raspberry Pi 5 / Arch Linux ARM**: repetir el mismo `os/install.sh` sobre aarch64, primero en
   `qemu-system-aarch64` y luego en el hardware real. Ajustar los paquetes que no existan en aarch64.
8. **Sonido** y **diseño del objeto** (anclas 6–8 de la marca): dependen del hardware.

## Próximos pasos hacia ARM real

Cuando la capa de escritorio esté estable en x86_64, se repite el mismo
`os/install.sh` sobre una imagen de Arch Linux ARM (aarch64), primero bajo
QEMU (`qemu-system-aarch64`) y luego en el Raspberry Pi 5 físico. El script
de instalación y los dotfiles son arquitectura-agnósticos: solo cambia la
base que se usa para construir/arrancar.
