# Cuentas, contraseñas y entrada al equipo

Cómo se entra en Command OS y dónde viven las cuentas. Léelo antes de tocar el primer arranque, la
pantalla de inicio de sesión, `greetd` o la creación de cuentas.

## Para quien usa el equipo

- **Primer arranque.** Un equipo nuevo no trae ninguna cuenta. Al encenderlo por primera vez, el
  asistente pide teclado, tu nombre (opcional), usuario y contraseña (al menos 8 caracteres, dos
  veces) y si quieres entrar sin contraseña al encender.
- **Tu cuenta administra el equipo.** La primera cuenta está en el grupo `wheel`: instala programas,
  actualiza y cambia el sistema con `sudo` y **su propia contraseña**. La cuenta `root` está
  bloqueada; toda la administración pasa por `sudo`. Lo dice el asistente y «acerca de cmd-os»
  (Super+F2) lo muestra como `cuenta  tu-usuario (administrador)`.
- **Al encender**, de serie, el equipo pide usuario y contraseña. Con inicio automático entra
  directamente; la pantalla se sigue bloqueando con la contraseña (inactividad, Super+L, tapa).
  Para cambiarlo: `command-os-login auto` o `command-os-login pedir` (sin argumentos, dice el modo
  actual). Se aplica en el siguiente arranque. Al cerrar sesión siempre aparece la pantalla de
  inicio de sesión.
- **Cambiar la contraseña:** `passwd` en una terminal. Es la misma para entrar, desbloquear y `sudo`.
- **Si la olvidas:** otra cuenta administradora la restablece con `sudo passwd tu-usuario`. Si no
  hay otra, desde un USB de Arch Linux: montar la raíz (en btrfs, `-o subvol=@`), `arch-chroot` y
  `passwd tu-usuario`. No hay puerta trasera de recuperación a propósito: sería un agujero.
- **Si la pantalla de inicio de sesión falla:** Ctrl+Alt+F2 abre una consola normal (tty2) donde
  entrar con usuario y contraseña y arreglarlo (`sudo systemctl restart greetd`, `journalctl -u
  greetd`).

## Privacidad

Las cuentas son cuentas normales de Linux y viven solo en el equipo (`/etc/passwd`, `/etc/shadow`).
La contraseña se guarda solo como hash (yescrypt) y no sale del equipo: no hay servidor, ni cuentas
en la nube, ni nada en el repositorio. El asistente se la pasa a `chpasswd` por la entrada estándar
(nunca como argumento, variable o registro); `tests/cuentas.sh` comprueba que no aparece en claro.

Límite: sin cifrado de disco, quien tenga el equipo en la mano puede leer los datos aunque no sepa
la contraseña (pendiente en `ROADMAP.md`).

## Cómo funciona

| Pieza | Qué hace |
| --- | --- |
| `greetd` (tty1) | Gestor de inicio de sesión. Lee `/etc/command-os/greetd.toml` (drop-in `greetd.service.d/command-os.conf`). |
| `lib/apply-login` | Genera ese `greetd.toml` desde el estado y activa greetd. Lo ejecutan el paquete en cada actualización, `crear-cuenta` y `command-os-login`. |
| `command-os-primer-arranque` + `lib/primer-arranque.py` | Asistente (GTK 4 en `cage`, como root) mientras no existe `/var/lib/command-os/configurado`. Código 3 = cambio de teclado: se reabre `cage` con la distribución nueva. |
| `lib/crear-cuenta` | Crea la cuenta (wheel), fija la contraseña por stdin, bloquea root, guarda teclado y marca el equipo como configurado. Si falla, no deja nada a medias. |
| `command-os-greeter` + `lib/greeter.py` | Pantalla de inicio de sesión (GTK 4 en `cage`, usuario `greeter`). Habla con greetd por `$GREETD_SOCK`; PAM lo hace greetd. |
| `lib/comun.py`, `lib/entorno-grafico` | Lo común de las dos ventanas (tema, logo, filas) y de los tres lanzadores (VM, teclado). |
| `command-os-session` | La sesión: prepara la cuenta (`command-os-user-setup`) y lanza labwc. Vale para cualquier cuenta. |
| `command-os-login` | Inicio automático (`initial_session`) o pedir contraseña. |

Estado: `/etc/command-os/cuenta-principal`, `/etc/command-os/inicio-automatico` (usuario, si lo hay),
`/etc/command-os/kb_layout` y `/var/lib/command-os/configurado`. Una variante con
`os/variants/<v>/inicio-automatico-de-serie` hace que el asistente proponga el inicio automático (para
el cyberdeck).

**Decisiones** (2026-10-07; con lo descartado, en `docs/decisiones.md`):
- Asistente de primer arranque en vez de preguntar al instalar: la misma imagen vale para cualquier
  equipo y la cuenta la elige quien lo recibe.
- Pedir contraseña de serie, inicio automático opcional: Command OS también se instala en PCs
  (portátiles, equipos compartidos, dual boot).
- Greeter propio en vez de ReGreet: ReGreet 0.5 no tiene traducciones (textos fijos en inglés) y
  su panel no sigue la marca. El nuestro comparte diseño con el asistente y no enseña selector de
  sesión. tuigreet (texto) se descartó por no seguir la marca.
- Contraseña mínima de 8 caracteres.

**Desarrollo:** `COMMAND_OS_DEV_USER=deck` en `install.sh` (lo pone `build-image.sh` con
`DEV_SSH_PUBKEY`) crea `deck`/`deck` con inicio automático y sin asistente. Nunca en un equipo que se
entrega.

**Equipos anteriores** (entraban con `agetty --autologin` en tty1): al actualizar el paquete,
`apply-login` los pasa a greetd con la misma cuenta e inicio automático, sin asistente, y quita el
bloque de labwc de su `.bash_profile`. Verificado en la VM x86 el 2026-10-07.
