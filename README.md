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
sobre Arch x86_64. Por eso la decisión fue **Arch Linux ARM + Hyprland,
modificado para llegar al mismo resultado que Omarchy**: misma idea de capa
curada (instalador + paquetes + dotfiles) sobre Arch, pero reconstruida por
nosotros y arquitectura-agnóstica.

**Estado respecto a esa meta**: `os/` hoy es una base Hyprland mínima
(Waybar, Wofi, Alacritty/Kitty) que valida el pipeline de instalación. Todavía
no replica la experiencia Omarchy (launcher, notificaciones, bloqueo/idle,
OSD, sistema de temas, apps y atajos por defecto) — ese es el trabajo de
producto pendiente una vez que se pueda ver Hyprland renderizado.

## Estructura

- `os/` — el producto: lista de paquetes (`packages.txt`), instalador
  (`install.sh`) y dotfiles (`dotfiles/`) para Hyprland/Waybar/Wofi/terminal.
  Esto es lo que se instala tanto en la VM de pruebas como, más adelante, en
  el Pi real.
- `build/packer/` — pipeline de build desatendido para la VM de desarrollo
  (QEMU, x86_64). Particiona disco, instala Arch base y corre
  `os/install.sh` sin intervención manual.
- `build/iso/` — ISOs descargadas (no versionadas, ver `.gitignore`).

## Flujo de desarrollo (VM x86_64 en QEMU)

Ver `docs/testing.md` para el ciclo completo de build → iteración, y por qué
se usa QEMU en vez de VirtualBox.

Esta VM valida que `os/install.sh` instala todo sin errores (paquetes,
dotfiles, servicios) — es el ciclo rápido para iterar cambios. La
verificación visual real de Hyprland (cómo se ve, animaciones, etc.) se hace
en el Raspberry Pi 5 físico: la GPU virtualizada en una VM de Windows tiene
problemas de compatibilidad conocidos con compositores Wayland que no vale
la pena perseguir (ver `docs/testing.md`).

## Próximos pasos hacia ARM real

Cuando el layer de Hyprland esté estable en x86_64, se repite el mismo
`os/install.sh` sobre una imagen de Arch Linux ARM (aarch64), primero bajo
QEMU (`qemu-system-aarch64`) y luego en el Raspberry Pi 5 físico. El script
de instalación y los dotfiles son arquitectura-agnósticos: solo cambia la
base que se usa para construir/arrancar.
