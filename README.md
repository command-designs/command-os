# Command OS

Distro propia para el cyberdeck, construida como una capa de curación
(compositor, theming, apps por defecto, instalador) sobre una base ya
mantenida por terceros — Arch Linux ARM en el hardware real (Raspberry Pi 5),
Arch Linux x86_64 en la VM de desarrollo. No reinventamos kernel ni
infraestructura de paquetes: usamos pacman tal cual.

**Instalar:** [`INSTALAR.md`](INSTALAR.md), con todas las formas (PC junto a Windows o en el disco
entero, máquina virtual, sobre un Arch ya instalado, imagen USB…).

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
tema de marca, notificaciones (swaync), bloqueo/idle (Hyprlock/Hypridle), OSD, splash de arranque,
atajos con su ayuda (Super+F1), apps por defecto, tienda de aplicaciones (Flatpak con Flathub, que
no toca el sistema), gestor de comprimidos y asistente de primer arranque con pantalla de
inicio de sesión propia (`docs/cuentas.md`), verificado en una VM x86_64. Falta probar varias piezas,
empaquetarlo y llevarlo al Pi real: ver "Siguientes pasos" más abajo.

## Estructura

- `os/` — el producto. El sistema es el paquete de pacman `command-os` (`pkg/PKGBUILD`): depende de
  `packages.txt` y lleva scripts (`bin/`, `lib/`), ganchos de pacman (`hooks/`) y del initramfs
  (`initcpio/`: la contraseña del disco cifrado en el splash), traducciones (`po/`, castellano de
  serie e inglés: [`docs/idioma.md`](docs/idioma.md)), marca (`branding/`), configuración de serie (`dotfiles/`, `system/`) y la fecha validada de Arch y la
  clave de firma (`pacman/`). `install.sh` prepara la máquina, construye el paquete y lo instala;
  las actualizaciones llegan después por pacman. Cómo funciona todo: [`docs/actualizaciones.md`](docs/actualizaciones.md).
- `tests/` y `.github/workflows/` — pruebas automáticas (sesión real sin pantalla, colores de la marca, escala de las
  pantallas, batería y aplicaciones fijadas de la barra, descargas y tipos de archivo, discos y cifrado
  del instalador, idioma y traducciones) en
  cada cambio y cada día, publicación firmada del paquete y validación de fechas de Arch.
- `build/packer/` — pipeline de build desatendido para la VM de desarrollo
  (QEMU, x86_64). Particiona disco, instala Arch base y corre
  `os/install.sh` sin intervención manual.
- `build/x86/` — instalación en un PC con el asistente `instalar.sh` (publicado y firmado: se descarga
  con `instalar-command-os.sh`, sin clonar nada): junto a Windows
  (`install-dualboot.sh`) o como sistema principal en el disco entero (`install-disco.sh`); guía en
  [`docs/instalacion.md`](docs/instalacion.md). También la imagen para probar desde un USB
  (`build-image.sh`). Raíz en btrfs con instantáneas (`lib.sh`), disco cifrado con LUKS2 si se quiere
  ([`docs/cifrado.md`](docs/cifrado.md)) y el Arch de la fecha validada.
- `build/iso/` — ISOs descargadas (no versionadas, ver `.gitignore`).

## Flujo de desarrollo (VM x86_64 en QEMU)

Ver `docs/testing.md` para el ciclo completo de build → iteración, y por qué
se usa QEMU en vez de VirtualBox.

Esta VM valida que `os/install.sh` instala todo sin errores (paquetes,
dotfiles, servicios) — es el ciclo rápido para iterar cambios. La
fluidez real del escritorio se juzga en el Raspberry Pi 5 físico o en bare metal: en la VM el
render es por software (ver `docs/testing.md`).

## Identidad y estado del tema

El escritorio sigue la marca v2 de Command (`BRAND.md` de `command-web`): casi monocromo, rojo solo como
señal. Detalle y estado de cada ancla de marca en [`docs/DISENO.md`](docs/DISENO.md). Los assets están
en `os/branding/` (logo, fuentes, fondos en 16:9 y 16:10, splash de arranque, tema de GRUB). Escala
de alta densidad y resoluciones: [`docs/notas/pantallas.md`](docs/notas/pantallas.md).

## Siguientes pasos

En [`ROADMAP.md`](ROADMAP.md), por orden.

## ARM: cuando haya hardware

**Por ahora la prioridad es x86** (PC y VM): todavía no se sabe qué hardware ARM llevará el cyberdeck,
así que no se hace nada específico de ARM hasta tenerlo. Entonces se repite el mismo
`os/install.sh` sobre una imagen de Arch Linux ARM (aarch64), primero bajo
QEMU (`qemu-system-aarch64`) y luego en el Raspberry Pi 5 físico. El script
de instalación y los dotfiles son arquitectura-agnósticos: solo cambia la
base que se usa para construir/arrancar.
