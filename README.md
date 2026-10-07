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

**Escritorio: labwc.** Es un producto para clientes: ventanas flotantes con barra de título y botones,
barra de tareas, Alt+Tab, menú con clic derecho y Super para abrir aplicaciones, que cualquiera
entiende sin explicación; y es ligero (sin animaciones de ventanas ni efectos caros), que en un
Raspberry Pi 5 importa. Es el mismo compositor que usa Raspberry Pi OS por defecto.

**Estado respecto a esa meta**: `os/` ya tiene escritorio labwc con tema de ventanas propio,
tema de marca, notificaciones (Mako), bloqueo/idle (Hyprlock/Hypridle), OSD, splash de arranque,
atajos con su ayuda (Super+F1), apps por defecto y asistente de primer arranque con pantalla de
inicio de sesión propia (`docs/cuentas.md`), verificado en una VM x86_64. Falta probar varias piezas,
empaquetarlo y llevarlo al Pi real: ver "Siguientes pasos" más abajo.

## Estructura

- `os/` — el producto. El sistema es el paquete de pacman `command-os` (`pkg/PKGBUILD`): depende de
  `packages.txt` y lleva scripts (`bin/`, `lib/`), ganchos de pacman (`hooks/`), marca
  (`branding/`), configuración de serie (`dotfiles/`, `system/`) y la fecha validada de Arch y la
  clave de firma (`pacman/`). `install.sh` prepara la máquina, construye el paquete y lo instala;
  las actualizaciones llegan después por pacman. Cómo funciona todo: [`docs/actualizaciones.md`](docs/actualizaciones.md).
- `tests/escritorio.sh` y `.github/workflows/` — pruebas automáticas (sesión real sin pantalla) en
  cada cambio y cada día, publicación firmada del paquete y validación de fechas de Arch.
- `build/packer/` — pipeline de build desatendido para la VM de desarrollo
  (QEMU, x86_64). Particiona disco, instala Arch base y corre
  `os/install.sh` sin intervención manual.
- `build/x86/` — imagen para USB (`build-image.sh`) e instalador en dual boot junto a Windows
  (`install-dualboot.sh`, guía en [`docs/dualboot.md`](docs/dualboot.md)). Raíz en btrfs con
  instantáneas (`lib.sh`) y el Arch de la fecha validada.
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

En [`ROADMAP.md`](ROADMAP.md), por orden.

## Próximos pasos hacia ARM real

Cuando la capa de escritorio esté estable en x86_64, se repite el mismo
`os/install.sh` sobre una imagen de Arch Linux ARM (aarch64), primero bajo
QEMU (`qemu-system-aarch64`) y luego en el Raspberry Pi 5 físico. El script
de instalación y los dotfiles son arquitectura-agnósticos: solo cambia la
base que se usa para construir/arrancar.
