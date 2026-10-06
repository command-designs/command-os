# Command OS — estabilidad y actualizaciones

Cómo se instala, se actualiza y se protege Command OS para que una actualización de Arch no rompa los
equipos de los clientes. Resumen: **el sistema es un paquete firmado, los equipos x86 se actualizan
contra una foto de Arch ya probada, cada actualización hace una instantánea para poder volver atrás
y unas pruebas automáticas avisan antes de que algo se rompa.**

## 1. Command OS es un paquete (`os/pkg`)

`command-os` (arquitectura `any`, igual para x86_64 y aarch64) depende de todo el escritorio
(`os/packages.txt`) y contiene scripts, marca, temas, sonidos, splash, fondos, ganchos de pacman y la
configuración de serie. `install.sh` lo construye desde el árbol y lo instala; después llega por
pacman.

**Configuración de serie en el sistema, cambios del usuario en `~/.config`.** Las actualizaciones
llegan a todos los equipos sin pisar nada personal:

| Programa | De serie | El usuario |
| --- | --- | --- |
| labwc | `/etc/xdg/labwc/` | `~/.config/labwc/` se **suma** (labwc arranca con `--merge-config`); ahí van sus escritorios |
| kitty, hyprlock, fastfetch, portales | `/etc/xdg/<programa>/` | una copia en `~/.config` la sustituye |
| Waybar, mako, hypridle, wofi | `/usr/share/command-os/config/<programa>/` | ídem; `command-os-config` elige cuál se usa |
| GTK 3/4, nano | `/usr/share/command-os/config/` | `command-os-user-setup` enlaza la de serie; si el usuario pone un archivo propio, se respeta |
| terminal | `/usr/share/command-os/config/bash/bashrc` | un bloque en `~/.bashrc` lo carga |

`command-os-user-setup` se ejecuta en cada inicio de sesión (rápido e idempotente): crea los enlaces
que falten y, la primera vez en una cuenta preparada por el `install.sh` antiguo, quita aquellas
copias completas de `~/.config` (marca `~/.config/command-os/layout-2`).

## 2. Ganchos de pacman (`os/hooks`)

Lo que una actualización de Arch deshace se vuelve a aplicar solo:

| Gancho | Cuando se actualiza | Qué hace |
| --- | --- | --- |
| `command-os-grub` | grub | arranque silencioso (`lib/apply-boot`) y regenera `grub.cfg` |
| `command-os-identity` | filesystem | os-release, issue y motd de Command OS (`lib/apply-identity`) |
| `command-os-icon-folders` | papirus-icon-theme | carpetas en gris |
| `command-os-splash` | el tema del splash | regenera el initramfs |

Además, al instalarse o actualizarse el propio paquete se ejecuta `lib/apply-system` (dconf,
identidad, splash, arranque silencioso y repositorios).

## 3. Bloqueo que no se rompe (`command-os-lock`)

Un bloqueo que falla deja el equipo abierto. Super+L, la inactividad y la suspensión pasan por
`command-os-lock`: si la configuración de hyprlock tiene errores (lo revisa antes de bloquear,
solo cuando cambian la configuración o hyprlock), usa una de emergencia; si hyprlock no arranca,
usa swaylock. Lo deja anotado en el registro (`journalctl -t command-os-lock`).

## 4. Arch de una fecha validada (x86_64)

Los equipos x86_64 no se actualizan contra el Arch del día, sino contra la foto del
[Arch Linux Archive](https://wiki.archlinux.org/title/Arch_Linux_Archive) de la fecha de
`os/pacman/snapshot-date`, que es la que se ha probado. `lib/apply-repos` lo configura
(`/etc/pacman.d/command-os-mirrorlist`, solo para core/extra/multilib: mezclar el archivo con
espejos del día no es seguro).

- **Actualizar un equipo:** `update` en la terminal (`command-os-update`): primero trae el paquete
  command-os (que puede traer una fecha nueva) y después todo el sistema contra esa fecha.
- **Validar una fecha nueva:** GitHub Actions → `fecha` → Run workflow (vacío = ayer). Prueba el
  escritorio con ese Arch y, solo si pasa, guarda la fecha en `main` y publica el paquete.
- **Servidor:** `/etc/command-os/archive-url` cambia el servidor del archivo. Con muchos equipos,
  lo correcto es un espejo propio del archivo
  ([archivetools](https://github.com/seblu/archivetools)) en vez del servidor de Arch.
- **Desarrollo:** `touch /etc/command-os/rolling` vuelve al Arch del día.
- **Raspberry Pi (aarch64):** Arch Linux ARM no publica fotos fechadas: el Pi usa sus espejos
  normales. Le protegen las instantáneas y las pruebas diarias; una foto propia exigiría un espejo
  propio de Arch Linux ARM.

## 5. Instantáneas (btrfs + snapper)

Las instalaciones nuevas (`build/x86/build-image.sh`, `install-dualboot.sh`) usan btrfs con
subvolúmenes (`build/x86/lib.sh`): `@` (el sistema, kernel incluido), `@home`, `@snapshots`,
`@var_log` y `@pkg`. `install.sh` configura snapper (10 instantáneas como mucho, solo las de pacman)
y snap-pac hace una **antes y otra después de cada operación de pacman**.

- **Volver atrás:** Esc al encender → menú de GRUB → instantáneas (grub-btrfs). Se arranca la
  instantánea en modo solo lectura con los cambios en memoria (gancho `grub-btrfs-overlayfs`, que
  necesita el initramfs clásico; install.sh lo cambia). Si todo va bien, `command-os-rollback` la
  deja como sistema y se reinicia. Sin arrancarla: `command-os-rollback N` (`--lista` para verlas).
- `/home` no retrocede: los archivos del usuario se quedan.
- Las instalaciones antiguas en ext4 no tienen instantáneas (convertirlas exige reinstalar).
- Raspberry Pi: no hay GRUB; `command-os-rollback N` funciona, pero el kernel está en la partición
  de arranque, fuera de las instantáneas.

## 6. Repositorio de paquetes y firma

- Público: `command-designs/command-os-repo`, Release `repo` (el código sigue privado). Los equipos
  lo añaden solos en cuanto responde (`lib/apply-repos`), con `SigLevel = Required`.
- Firma: clave ed25519, huella en `os/pacman/command-os.fingerprint`, pública en
  `os/pacman/command-os.gpg`. La privada está solo en el secreto `COMMAND_OS_GPG_KEY` de GitHub y en
  la copia de seguridad fuera de línea del responsable. Si se pierde, hay que generar otra y
  publicar un paquete que traiga la nueva pública firmado con la antigua.
- Publicación: `.github/workflows/publicar.yml`, en cada cambio de `os/` en `main`. Secretos:
  `COMMAND_OS_GPG_KEY` y `COMMAND_OS_REPO_TOKEN` (token con escritura en el repositorio público).

## 7. Pruebas automáticas (`tests/escritorio.sh`, `.github/workflows/pruebas.yml`)

En cada cambio y cada día: sintaxis y shellcheck de los scripts, y una sesión real de labwc sin
pantalla con el paquete instalado (labwc lee su configuración sin errores; Waybar, mako, hypridle y
el fondo arrancan; las configuraciones de hyprlock son válidas; captura de pantalla en los
artefactos). Se ejecuta contra el Arch de la fecha validada (lo que tienen los equipos) y contra el
Arch del día (lo que llegará): si la del día falla, no se valida una fecha nueva hasta arreglarlo.
