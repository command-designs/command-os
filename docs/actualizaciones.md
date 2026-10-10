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
- `/boot/grub` tampoco: `command-os-rollback` pone en el sistema recuperado el del anterior. El de la
  instantánea tiene la lista del menú desfasada, módulos que pueden no casar con el GRUB de la
  partición EFI (que no retrocede) y, en las instantáneas de la imagen, ni existe.
- **Prueba automática de `command-os-rollback`** (`tests/rollback.sh`, trabajo `rollback` de la CI): un
  btrfs de verdad en un disco loop, con una raíz mínima (busybox estático y un `pacman` y un `mkinitcpio`
  de mentira para el chroot). Cubre volver sin y con `/boot` aparte (el kernel de la instantánea y su
  initramfs vuelven a `/boot`; si el kernel ya coincide no se rehace nada), que un fallo a medias
  (`mkinitcpio` que falla) deja la raíz, `/boot` y las copias como estaban, y que la confirmación
  equivocada, una instantánea inexistente, un argumento inválido y la falta de `/.snapshots` no tocan
  nada. El script lee `COMMAND_OS_LIB`, `COMMAND_OS_SNAPSHOTS` y `COMMAND_OS_BOOT` solo para eso (por
  defecto, las rutas del sistema). Lo que **no** cubre: el arranque real desde GRUB y el reinicio (se
  prueba a mano en `command-os-btrfs`, `docs/notas/estabilidad.md`) ni los kernels de varios paquetes.
- Las instalaciones antiguas en ext4 no tienen instantáneas (convertirlas exige reinstalar).
- Raspberry Pi: no hay GRUB; `command-os-rollback N` funciona, pero el kernel está en la partición
  de arranque, fuera de las instantáneas.

## 6. Repositorio de paquetes y firma

- Público: `command-designs/command-os-versions`, Release `repo` (el código sigue privado). En la
  Release `instalador`, el instalador firmado (`command-os-instalador.tar.gz`: scripts de `build/x86`
  y el árbol `os/`), `instalar-command-os.sh`, que lo descarga y comprueba, y la clave pública
  ([`instalacion.md`](instalacion.md) § 2). Los equipos
  lo añaden solos en cuanto responde (`lib/apply-repos`), con `SigLevel = Required`.
- Firma: clave ed25519, huella en `os/pacman/command-os.fingerprint`, pública en
  `os/pacman/command-os.gpg`. La privada está solo en el secreto `COMMAND_OS_GPG_KEY` de GitHub y en
  la copia de seguridad fuera de línea del responsable. Si se pierde, hay que generar otra y
  publicar un paquete que traiga la nueva pública firmado con la antigua.
- Publicación: `.github/workflows/publicar.yml`, en cada cambio de `os/` o `build/x86/` en `main`. El
  paquete solo se publica si cambia `os/` (un cambio del instalador no avisa a los equipos de una
  actualización vacía); el instalador, siempre, con la versión del paquete publicado. Secretos:
  `COMMAND_OS_GPG_KEY` y `COMMAND_OS_VERSIONS_TOKEN` (token con escritura en el repositorio público).

## 7. Aviso de actualizaciones en el escritorio

Una comprobación periódica **sin tocar el sistema** y un aviso en la barra de Waybar. Instalar sigue
siendo `command-os-update`, con la contraseña y el «¿continuar?» de pacman.

| Pieza | Qué hace |
| --- | --- |
| `command-os-check-updates.timer` | 10 min después de arrancar y cada 6 h (retraso al azar de hasta 15 min); lanza `command-os-check-updates@auto.service`. Se activa una sola vez (`lib/apply-system`, marca `/var/lib/command-os/aviso-actualizaciones`): si el usuario lo desactiva, las actualizaciones no lo vuelven a activar. |
| `command-os-check-updates@.service` | `lib/check-updates` como root, con el sistema de archivos en solo lectura (solo escribe `/var/lib/command-os` y `/var/cache/command-os`). La instancia es el modo: `auto` o `manual`. |
| `lib/check-updates` | Ejecuta `checkupdates` (pacman-contrib: sincroniza una **copia** de la base de datos en `/var/cache/command-os/checkup-db`, no la real) y guarda el resultado en `/var/lib/command-os/updates`: primera línea la hora, después `paquete antes -> después`. Si falla, conserva el resultado anterior; si falla con una copia mala, la borra y reintenta de cero. En `auto` no hace nada con una conexión de datos medidos (NetworkManager); `manual` comprueba siempre. |
| `hooks/command-os-updates.hook` | Tras cada operación de pacman vuelve a comprobar (`lib/refresh-updates`; solo con systemd en marcha y fuera de un chroot): el aviso no enseña lo que ya está instalado. |
| `os/system/polkit-check-updates.rules` | Quien está en el equipo (sesión local y activa) puede lanzar `command-os-check-updates@manual.service`, y solo esa unidad, sin contraseña. |
| `os/bin/command-os-updates` | `status` (JSON para Waybar), `update`, `check`, `notify`, `watch` (autostart de labwc). |

- **Barra:** oculta si no hay nada. `upd N` (N = command-os más el resto); el número va en ámbar si hay
  versión nueva de command-os. Tooltip con las versiones, la lista de paquetes y cuándo se comprobó.
  Si pacman cambió algo **después** de la comprobación, el módulo se oculta hasta la siguiente (lo que
  decía ya no vale).
- **Clic:** abre kitty con `command-os-update` (`sudo` pide la contraseña, pacman pregunta antes de
  instalar, la terminal espera Intro para cerrarse; si ya hay una abierta, avisa). **Clic derecho:**
  comprueba ahora y lo cuenta en una notificación.
- **Notificación:** una sola por cada versión nueva de command-os (la última avisada queda en
  `~/.local/state/command-os/updates-notified`); clic en ella = actualizar. Los paquetes sueltos de
  Arch solo salen en la barra: con Arch del día cambian a diario y avisar sería ruido.
- **Con la fecha validada (x86):** una versión nueva de command-os trae una fecha nueva de Arch, así que
  los paquetes de esa fecha solo se ven tras instalarla; el tooltip lo dice.
- **Al terminar `command-os-update`** avisa si hay que reiniciar (los módulos del kernel en marcha ya
  no están en el disco).
- **Tras volver atrás con `command-os-rollback`** el aviso sigue siendo correcto sin hacer nada. El
  resultado (`/var/lib/command-os/updates`) y la base de datos de pacman van dentro de `@`, así que
  vuelven juntos, y la instantánea conserva las fechas de los archivos: la regla «la comprobación tiene
  que ser posterior al último cambio de pacman» se cumple o no con el estado recuperado, nunca con uno
  mezclado. Si la instantánea no trae un resultado válido, la barra se oculta hasta la siguiente
  comprobación (10 min tras arrancar). `/home` no vuelve atrás: si se vuelve de una versión nueva de
  command-os que ya se había avisado, no se avisa otra vez de ella (`updates-notified`). Verificado en
  `command-os-btrfs` con un `checkupdates` de mentira, instalando un paquete y volviendo a la
  instantánea anterior a la instalación, a la posterior y a una anterior a toda la prueba.
- **Probar a mano:** `systemctl start command-os-check-updates@manual.service` y `cat
  /var/lib/command-os/updates`. Para simular una versión nueva, construir dos versiones con
  `COMMAND_OS_PKGVER` y poner la nueva en un repositorio local fuera de `/tmp` (la unidad tiene su
  propio `/tmp`) con `SigLevel = Optional TrustAll`. Si se cambia de repositorio, borrar los `.sig` viejos
  de `/var/lib/pacman/sync` o pacman da «signature is invalid».

## 8. Pruebas automáticas (`tests/*.sh`, `.github/workflows/pruebas.yml`)

En cada cambio y cada día: sintaxis y shellcheck de los scripts, y una sesión real de labwc sin
pantalla con el paquete instalado (labwc lee su configuración sin errores; Waybar, mako, hypridle y
el fondo arrancan; las configuraciones de hyprlock son válidas; captura de pantalla en los
artefactos). Se ejecuta contra el Arch de la fecha validada (lo que tienen los equipos) y contra el
Arch del día (lo que llegará): si la del día falla, no se valida una fecha nueva hasta arreglarlo.
Además: `tests/cuentas.sh` (entrada al equipo) y `tests/actualizaciones.sh` (lo que enseña la barra, la
comprobación con un `checkupdates` de mentira, las unidades de systemd), sin red ni pantalla, y
`tests/rollback.sh` (`command-os-rollback` sobre un btrfs en un disco loop, ver § 5).
