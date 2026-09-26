# Command OS

Distro propia para el cyberdeck, construida como una capa de curación
(compositor, theming, apps por defecto, instalador) sobre una base ya
mantenida por terceros — Arch Linux ARM en el hardware real (Raspberry Pi 5),
Arch Linux x86_64 en la VM de desarrollo. No reinventamos kernel ni
infraestructura de paquetes: usamos pacman tal cual.

## Estructura

- `os/` — el producto: lista de paquetes (`packages.txt`), instalador
  (`install.sh`) y dotfiles (`dotfiles/`) para Hyprland/Waybar/Wofi/terminal.
  Esto es lo que se instala tanto en la VM de pruebas como, más adelante, en
  el Pi real.
- `build/packer/` — pipeline de build desatendido para la VM de desarrollo
  (VirtualBox, x86_64). Particiona disco, instala Arch base y corre
  `os/install.sh` sin intervención manual.
- `build/iso/` — ISOs descargadas (no versionadas, ver `.gitignore`).

## Flujo de desarrollo (VM x86_64 en VirtualBox)

Ver `docs/testing.md` para el ciclo completo de build → snapshot → iteración.

## Próximos pasos hacia ARM real

Cuando el layer de Hyprland esté estable en x86_64, se repite el mismo
`os/install.sh` sobre una imagen de Arch Linux ARM (aarch64), primero bajo
QEMU (`qemu-system-aarch64`) y luego en el Raspberry Pi 5 físico. El script
de instalación y los dotfiles son arquitectura-agnósticos: solo cambia la
base que se usa para construir/arrancar.
