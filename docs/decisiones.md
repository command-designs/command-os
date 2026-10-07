# Decisiones

Decisiones no obvias: qué se decidió, por qué y qué se descartó, para no reabrirlas. Las anteriores
al 2026-10-07 están repartidas por `docs/` y `AGENTS.md` («Qué se probó y qué se descartó»).

## 2026-10-07 — Cifrado del disco (`docs/cifrado.md`)

- **Opcional y marcado por defecto, en disco entero y en dual boot.** En un portátil con Windows
  cifrado por BitLocker, un Linux sin cifrar al lado sería el punto débil. La imagen USB
  (`build-image.sh`) no se cifra: es genérica y no hay a quién pedirle la contraseña. Descartado:
  siempre cifrado (hay equipos donde no se quiere, como un banco de pruebas) y desmarcado por defecto
  (casi nadie lo marcaría).
- **`/boot` en una partición aparte sin cifrar; GRUB no descifra nada.** Así la contraseña se pide una
  sola vez y dentro del splash. Descartado: `/boot` cifrado con `GRUB_ENABLE_CRYPTODISK` (GRUB la pide
  antes del splash en modo texto, tarda con argon2id y hay que pedirla dos veces o meter una clave en el
  initramfs). Coste aceptado: el kernel sale de las instantáneas; `command-os-rollback` pone el de la
  instantánea y rehace su initramfs.
- **Clave de recuperación que guarda el usuario**, en una segunda ranura de LUKS: generada en el
  equipo, enseñada una vez y comprobada con dos grupos al azar; nadie más tiene copia. No es una puerta
  trasera (esa sería una forma de entrar del fabricante): es como la de BitLocker, pero sin copia en
  ningún servidor. Solo cifras, para teclearla en cualquier distribución de teclado; se acepta con o
  sin guiones. Descartado: nada (un olvido = perderlo todo) y guardarla en el equipo o en la nube.
- **Gancho propio del initramfs (`command-os-cifrado`) antes de `encrypt`.** El de Arch pide en inglés
  y, tras 3 fallos, deja una consola de emergencia. El propio pide en castellano dentro del splash,
  sin límite de intentos, y `encrypt` lo respeta («Device already exists»). Descartado: copiar y
  modificar `encrypt` (habría que seguirle los cambios) y pasar al initramfs de systemd (`sd-encrypt`),
  que rompe el arranque de instantáneas (`grub-btrfs-overlayfs` solo va en el de udev).
- **LUKS2 con argon2id y TRIM (`allow-discards`) guardado en la cabecera.** TRIM alarga la vida del
  SSD y mantiene su rendimiento; a cambio se ve qué zonas están libres, no lo que contienen.
- **Contraseña de 8 caracteres como mínimo, sin ñ ni tildes.** Igual que las cuentas; argon2id frena
  la fuerza bruta. Sin ñ ni tildes porque se teclea antes de que arranque el sistema: si el teclado no
  las diera, no se podría entrar.
- **Todo se pregunta antes de la confirmación del borrado**: después no hay más preguntas y, si se
  cancela, no se ha tocado nada.

## 2026-10-07 — Idioma del sistema (punto 10 del roadmap)

- **Castellano de serie y elección de idioma en el asistente de primer arranque** (decisión del
  usuario). El producto habla en castellano; con `en_US` el menú de GRUB y los programas sin
  traducción propia salían en inglés. Elegirlo en el asistente deja usar el equipo en otro idioma sin
  reinstalar. Descartado: solo castellano fijo (cierra la puerta a otros idiomas) y dejarlo en `en_US`.

## 2026-10-07 — Pantallas 16:9 y 16:10 y alta densidad (`docs/notas/pantallas.md`)

- **Escala automática fraccionaria (pasos de 0,25)**, por la densidad del monitor y con tope de
  720 px de alto útil. Es lo que se ve del tamaño justo en portátiles de 13–16". Coste aceptado: las
  apps antiguas por XWayland se ven algo borrosas a escala no entera. Descartado: solo 1 o 2 (muchos
  portátiles quedan demasiado grandes o pequeños) y escala 1 fija con wdisplays (no se guarda ni
  llega al inicio de sesión).
- **Referencia 120 ppp en paneles internos y 110 en monitores**: los internos se miran más de cerca.
  Con estos valores salen las escalas habituales de cada tamaño (Windows y GNOME rondan lo mismo).
- **Un vigilante por sondeo (`wlr-randr` cada 2 s) en vez de kanshi**: kanshi necesita perfiles
  por monitor; aquí la escala sale sola. labwc no avisa de pantallas nuevas a un script.
- **Fondos en 16:9 y 16:10 en vez de uno con margen de seguridad**: cada pantalla ve la composición
  entera y nítida. Pesa poco (~2,7 MB más). Descartado: un único 16:10 (en 16:9 recortaría arriba y abajo).
- **hyprlock con la configuración escalada al bloquear**: hyprlock ignora la escala de labwc. Solo la
  de serie; la de una cuenta se respeta tal cual.
- **Tema de GRUB generado al instalar para la pantalla del equipo**: GRUB no escala fuentes ni
  imágenes. Descartado: forzar GRUB a 1920x1080 (borroso y deformado en 16:10) y un tema fijo.
- **Splash en proporción al alto de la pantalla**, con fotogramas a doble resolución.

## 2026-10-07 — Prioridad x86

- **Se trabaja y se prueba en x86; nada específico de hardware ARM por ahora.** No se sabe qué placa
  ARM llevará el cyberdeck (la Raspberry Pi 5 era una suposición). Command OS sigue siendo para las dos
  arquitecturas (paquete `any`), pero la imagen ARM, el arranque de la placa y las pruebas en ARM se
  aparcan hasta tener el hardware. Descartado: seguir con la Pi 5 a ciegas (trabajo que puede no
  servir con otra placa).

## 2026-10-07 — Entrada al equipo (`docs/cuentas.md`)

- **Asistente de primer arranque, no pregunta al instalar.** La misma imagen vale para cualquier
  equipo y la cuenta la elige quien lo recibe. Descartado: preguntar en el instalador (la cuenta la
  pondría quien prepara el equipo).
- **Pedir contraseña de serie; inicio automático opcional.** Command OS también se instala en PCs
  (portátiles, equipos compartidos, dual boot). Las variantes de dispositivo (cyberdeck) proponen el
  inicio automático en el asistente. Descartado: inicio automático siempre (inseguro en un PC) y
  nunca (rompe el arranque limpio del cyberdeck).
- **Primera cuenta administradora, root bloqueado.** Sin administrador el equipo no se mantiene;
  `sudo` deja registro. Las cuentas que se añadan después serán normales de serie.
- **Greeter propio (GTK 4 en cage) en vez de ReGreet.** ReGreet 0.5 no tiene traducciones (textos
  fijos en inglés) y su panel no sigue la marca. Descartados también tuigreet (texto, no sigue la
  marca) y GDM/SDDM (pesados, arrastran otro escritorio).
- **Contraseña mínima de 8 caracteres.**
- **Sin recuperación de contraseña propia:** otra cuenta administradora o un USB de rescate. Una
  puerta trasera sería un agujero.

## 2026-10-07 — Instalar como sistema principal (`docs/instalacion.md`)

- **Dos formas de instalar en un PC: junto a Windows o como sistema principal**, con un asistente
  común (`build/x86/instalar.sh`) y un script por modo. La imagen USB (`build-image.sh`) se queda para
  probar sin instalar. Descartado: un único script con opciones (el modo que borra quedaría a un
  parámetro de distancia del que no borra).
- **Seguridad antes que comodidad en el borrado:** disco siempre indicado a mano, sin valor por
  defecto; se rechazan el USB en vivo, el sistema en marcha, discos montados, con swap o volúmenes en
  uso, particiones, solo lectura y < 30 GB; la confirmación es escribir el nombre exacto del disco (y
  `BORRAR WINDOWS` si lo hay). Solo corre desde el USB en vivo de Arch: no se puede lanzar por error
  en un equipo instalado. Descartado: confirmar con «SI» (se teclea sin leer) y elegir el disco más
  grande solo (puede ser el de los datos).
- **GPT con EFI de 1 GiB y btrfs para el resto, sin swap.** Igual que el dual boot y la imagen (mismas
  instantáneas y `command-os-rollback`). 1 GiB deja sitio a varios kernels si algún día van a la EFI.
- **GRUB con entrada en la NVRAM y además `EFI/BOOT/BOOTX64.EFI`:** hay firmwares que pierden u
  ordenan mal las entradas; la copia de reserva arranca igual. En el dual boot no se pone (es el
  arranque de reserva de Windows).
- **Lo común del dual boot y el disco entero en `build/x86/lib.sh`** (`install_base`,
  `configure_system`); `build-image.sh` se queda aparte porque hace una imagen genérica (zona UTC,
  cuenta de desarrollo, sin NVRAM).
- **Antes de `grub-install`, se borran las entradas `command-os` viejas de la NVRAM**
  (`forget_nvram_entries`): GRUB no actualiza una entrada con su misma ruta aunque apunte a otra
  partición, y al reinstalar la BIOS seguiría una entrada muerta (en dual boot, arrancaría Windows sin menú).
- **Menú de GRUB sin las entradas «EFI BootNext»** (`GRUB_DISABLE_BOOTNEXT=true`, `os/lib/apply-boot`):
  GRUB 2.16 copia en el menú la NVRAM del momento (USB, discos sueltos, Windows repetido).
- **Sin cifrado de disco en este paso:** pide la contraseña antes del splash y toca el initramfs y
  grub-btrfs; va como punto propio del roadmap (hecho después: «Cifrado del disco», arriba).

## 2026-10-07 — Aviso de actualizaciones (`docs/actualizaciones.md` § 7)

- **Comprobar a los 10 min de arrancar y cada 6 h, con retraso al azar.** Las versiones salen pocas
  veces al día; con muchos equipos, el azar evita que pregunten todos a la vez. Descartado: una vez al
  día (un equipo que se enciende un rato corto tarda en enterarse) y cada hora (más tráfico sin ganar nada).
- **Una comprobación por equipo, no por cuenta:** temporizador del sistema que escribe un archivo que lee
  la barra. Descartado: un servicio de usuario por cuenta (duplica descargas, no corre sin sesión y
  depende del entorno gráfico).
- **`checkupdates` (copia de la base de datos de pacman), nunca `pacman -Sy`:** sincronizar la real sin
  actualizar deja el equipo con bases de datos mezcladas (la causa clásica de roturas en Arch).
- **No se comprueba con datos medidos** (solo en automático); a mano, siempre. Un cyberdeck puede
  compartir los datos del móvil.
- **Notificación solo por versión nueva de command-os, una vez, con clic = actualizar.** Los paquetes de
  Arch sueltos solo salen en la barra (con Arch del día cambian a diario). Descartado: notificación crítica
  (se queda fija y es para fallos) y repetirla cada vez que se comprueba.
- **Actualizar abre `command-os-update` en una terminal, no un panel propio.** Se ve qué cambia, `sudo` y
  pacman piden confirmación y el resultado queda a la vista. Un panel gráfico necesitaría un agente de
  polkit para instalar y resolver a ciegas las preguntas de pacman (conflictos, sustituciones): si sale
  mal, el equipo queda a medias. Se retomará si hace falta.
- **Polkit deja lanzar la comprobación manual (solo ella, `start`) a la sesión local activa:** un clic
  derecho no debe pedir contraseña por mirar. Instalar sigue exigiendo `sudo`.
- **Si pacman cambia algo después de la comprobación, la barra la ignora** hasta la siguiente (y el gancho
  de pacman la repite al terminar): nunca enseña un aviso de algo ya instalado.

## 2026-10-07 — Volver atrás (`command-os-rollback`)

- **El sistema recuperado usa el `/boot/grub` del anterior.** Descartado: regenerar la lista en el
  primer arranque (no arregla los módulos que no casan con la partición EFI ni las instantáneas de la
  imagen, que no tienen `/boot/grub`).

## 2026-10-07 — Clave de firma

- **Clave nueva al perder la anterior**, sin transición firmada: aún no se había publicado ningún
  paquete, así que ningún equipo confiaba en la antigua.
