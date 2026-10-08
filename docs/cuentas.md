# Cuentas, contraseñas y entrada al equipo

Cómo se entra en Command OS y dónde viven las cuentas. Léelo antes de tocar el primer arranque, la
pantalla de inicio de sesión, `greetd` o la creación de cuentas.

## Para quien usa el equipo

- **Primer arranque.** Un equipo nuevo no trae ninguna cuenta. Al encenderlo por primera vez, el
  asistente pide idioma (castellano o inglés; [`idioma.md`](idioma.md)), teclado, zona horaria
  (abajo, «Hora»), tu nombre (opcional), usuario y contraseña (al menos 8 caracteres, dos veces) y
  si quieres entrar sin contraseña al encender.
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

## Hora

- **Zona horaria en el asistente.** La fila «zona horaria» enseña la elegida con su diferencia con
  UTC y la hora; al pulsarla se abre un buscador: ciudad, país (en el idioma de la ventana, en
  castellano o en inglés) o el nombre de la zona, sin tildes y por comienzo de palabra («madr»,
  «estados unidos», «bogota»). Nombre y usuario comparten fila para que quepa en 720 px de alto. Sale
  marcada la que dejó el instalador; al cambiar a un teclado de un país (es, pt, gb, fr, de, it) se
  propone su zona principal, salvo que ya se haya elegido otra a mano o la marcada ya sea de ese país
  (Canarias sigue en Canarias con teclado español). Se aplica al crear la cuenta, como el idioma; si
  crear la cuenta falla, la zona vuelve a la de antes.
- **Cambiarla después:** `command-os-zona-horaria Europe/London` (pide `sudo`); sin argumentos dice
  la actual y `command-os-zona-horaria lista` enseña todas. La barra se reinicia sola con la hora nueva.
- **Hora por la red:** `systemd-timesyncd`, activado de serie (servidores de Arch). Si se desactiva
  con `systemctl disable`, una actualización no lo vuelve a activar, y si el equipo ya usa chrony,
  ntpd u openntpd, no se toca.
- **Dual boot:** el reloj del equipo va en hora local, como en Windows (`/etc/adjtime` → `LOCAL`). Al
  cambiar la zona, `command-os-zona-horaria` decide qué reloj manda: sin hora de la red (el primer
  arranque, casi siempre), el del equipo, que Windows deja en la hora de pared, y se vuelve a leer
  con la zona nueva; con hora de la red, el del sistema, y `timedatectl` reescribe el del equipo. En
  disco entero el reloj del equipo va en UTC y no se toca. Por eso el asistente, con el reloj en hora
  local y sin red, enseña la misma hora en todas las zonas: es la hora de pared.
- **Cómo se ha probado** (2026-10-08): `tests/zona-horaria.sh` y `tests/cuentas.sh` (CI: lista,
  rechazos, qué reloj manda en cada caso con órdenes falsas, búsqueda, sugerencias y timesyncd). VM
  `command-os-instalador`, instalando en inglés en un disco temporal y con `/etc/adjtime` en `LOCAL`,
  el reloj de la VM en la hora de Nueva York (desfase de −4 h) y sin red: el asistente enseñaba la hora
  de pared, al elegir New York el sistema pasó de 23:25 a la hora UTC real y la pantalla de inicio de
  sesión marcó la de Nueva York; ya con red y NTP, `command-os-zona-horaria Europe/London` reescribió el
  reloj del equipo a la hora de Londres sin mover la UTC y la barra cambió sola. Asistente a 1024x768 y
  1280x720: cabe entero. Sin probar: un dual boot con Windows de verdad (lo prueba el usuario).

## Privacidad

Las cuentas son cuentas normales de Linux y viven solo en el equipo (`/etc/passwd`, `/etc/shadow`).
La contraseña se guarda solo como hash (yescrypt) y no sale del equipo: no hay servidor, ni cuentas
en la nube, ni nada en el repositorio. El asistente se la pasa a `chpasswd` por la entrada estándar
(nunca como argumento, variable o registro); `tests/cuentas.sh` comprueba que no aparece en claro.

Límite: la contraseña de la cuenta no protege los datos si alguien se lleva el equipo; para eso está
el cifrado del disco, que el instalador propone de serie ([`cifrado.md`](cifrado.md)).

## Cómo funciona

| Pieza | Qué hace |
| --- | --- |
| `greetd` (tty1) | Gestor de inicio de sesión. Lee `/etc/command-os/greetd.toml` (drop-in `greetd.service.d/command-os.conf`). |
| `lib/apply-login` | Genera ese `greetd.toml` desde el estado y activa greetd. Lo ejecutan el paquete en cada actualización, `crear-cuenta` y `command-os-login`. |
| `command-os-primer-arranque` + `lib/primer-arranque.py` | Asistente (GTK 4 en `cage`, como root) mientras no existe `/var/lib/command-os/configurado`. Código 3 = cambio de teclado: se reabre `cage` con la distribución nueva. |
| `lib/crear-cuenta` | Crea la cuenta (wheel), fija la contraseña por stdin, aplica la zona horaria (`command-os-zona-horaria`) y el idioma (`command-os-idioma`), bloquea root, guarda teclado y marca el equipo como configurado. Si falla, no deja nada a medias (zona incluida). |
| `command-os-zona-horaria` + `lib/zonas.py` | La única forma de cambiar la zona (`/etc/localtime`, atómico; reloj del equipo en hora local, arriba); `actual` da el nombre de la actual a otros programas. `zonas.py`: lista (`zone.tab` y UTC), países traducidos (`iso-codes`), búsqueda y sugerencia por teclado del asistente, sin GTK. |
| `command-os-greeter` + `lib/greeter.py` | Pantalla de inicio de sesión (GTK 4 en `cage`, usuario `greeter`). Habla con greetd por `$GREETD_SOCK`; PAM lo hace greetd. |
| `lib/comun.py`, `lib/entorno-grafico` | Lo común de las dos ventanas (tema, logo, filas, traducciones) y de los tres lanzadores (VM, teclado, idioma). |
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
