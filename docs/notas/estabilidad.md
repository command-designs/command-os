# Notas: estabilidad, ganchos y bloqueo

Detalle movido de `CLAUDE.md` sin cambios (2026-10-06). Cómo funciona todo: `docs/actualizaciones.md`.

## Estabilidad (2026-10-06, rama `estabilidad`)

- Repositorio público de paquetes: `command-designs/command-os-versions` (creado por el usuario el
  2026-10-06). Secretos de repositorio en `command-os`: `COMMAND_OS_GPG_KEY` y `COMMAND_OS_VERSIONS_TOKEN`
  (creados por el usuario; la clave privada salió de `C:\Users\danie\command-os-firma\`, que el
  usuario debe guardar fuera del PC y borrar). Los equipos añaden el repositorio en cuanto existe
  su base de datos (lib/apply-repos solo lo añade si responde).
- XML de labwc: **ningún comentario puede contener `--`** (p. ej. `--merge-config`): labwc deja de
  leer el archivo entero y arranca sin configuración. Pasó y lo detectó el log.
- labwc suma las listas de escritorios al combinar configuraciones: la de serie no lleva `<names>`.
- Waybar ya trae `/etc/xdg/waybar/`: nuestra configuración de serie va en
  `/usr/share/command-os/config/waybar/` y se pasa con `--config/--style` (command-os-config).
- hyprlock con errores de configuración **no sale**: bloquea con la pantalla en negro y sin campo.
  `command-os-lock` revisa la configuración antes (hyprlock contra una pantalla inexistente lee la
  configuración y aborta; resultado guardado por huella para no generar un volcado en cada bloqueo).
- El reposo del PC congela la VM de VirtualBox (pasó dos veces): apagarla antes. Recuperación en la
  sección de VirtualBox más abajo.
- `runuser` conserva el entorno de root: `as_user` en install.sh fija HOME. Dentro de un chroot
  `systemd-detect-virt` ve el anfitrión (WSL): `is_vm` lo descarta.
- WSL cierra los procesos lanzados con `setsid nohup` al terminar `wsl.exe`: para construir
  imágenes, dejar `wsl.exe` en primer plano (en segundo plano desde la herramienta).
- **VM `command-os-btrfs`** (VirtualBox, SSH `127.0.0.1:2903`, disco
  `build/x86/vbox/command-os-btrfs.vdi`): imagen de `build-image.sh` con btrfs (VARIANT=vbox,
  DEV_SSH_PUBKEY). Convertir: `qemu-img convert -O vdi` dentro de WSL (VBoxManage no abre rutas
  `\\wsl.localhost`). Verificado en ella: subvolúmenes y fstab sin subvolid, snapper con pares
  antes/después de pacman, `command-os-rollback N` (el paquete instalado desaparece, `/home` se
  conserva, arranca del @ nuevo) y arrancar una instantánea desde GRUB (raíz `overlay` sobre
  `@snapshots/N/snapshot`, escritorio completo). Para llegar al menú de GRUB por teclado:
  `controlvm keyboardputscancode 01 81` (Esc) **después** de que pase el firmware (si no, abre el
  setup UEFI: elegir Continue).
- Pendiente: tras un retroceso, la lista de instantáneas de GRUB (`grub-btrfs.cfg` dentro del @
  recuperado) no se regenera hasta la siguiente instantánea. `shellcheck` no se ha ejecutado en
  local (lo hace `pruebas.yml`).
