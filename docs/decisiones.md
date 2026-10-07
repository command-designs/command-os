# Decisiones

Decisiones no obvias: qué se decidió, por qué y qué se descartó, para no reabrirlas. Las anteriores
al 2026-10-07 están repartidas por `docs/` y `AGENTS.md` («Qué se probó y qué se descartó»).

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
