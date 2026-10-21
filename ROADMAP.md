# Command OS — hoja de ruta

Por orden. Cuando algo se termina y se verifica, se quita de aquí (el detalle queda en `AGENTS.md`,
`docs/` y el historial de git). **Prioridad x86**: se trabaja y se prueba en x86; nada específico
de hardware ARM hasta saber qué placa lleva el cyberdeck (`AGENTS.md`).

## Lo prueba el usuario

Guía ordenada, para seguir con una sola instalación en un PC real: `docs/prueba-en-pc-real.md`.

## Aparcado hasta tener el hardware ARM del cyberdeck

- **Imagen ARM con btrfs** (antes punto 8): script de construcción para ARM (subvolúmenes, snapper,
  arranque de la placa que se elija) y validar los paquetes en aarch64, con la variante del cyberdeck
  (`os/variants/<v>/inicio-automatico-de-serie`: el asistente propone entrar sin contraseña). Se
  retoma cuando se sepa la placa; no tiene por qué ser una Raspberry Pi 5.
- **Diseño del objeto y anclas 6–8 de la marca** (`docs/DISENO.md`): dependen del hardware.

## Pendientes (por orden)

Lo que pidió el usuario el 2026-10-20 tras instalarlo en su portátil: que sea fiel de verdad a la
marca 2.1 (`lenguaje.html`), con movimiento fluido y gratificante (BRAND § 9; inspiración RSI de Star
Citizen, sin salirse de lo que § 9.3 prohíbe) y más fácil de usar en lo cotidiano. Tres tandas, un PR
por tanda. Llega como actualización normal (sin reinstalar); lo que el usuario tenga en `~/.config`
se migra con marca, como `layout-2`, sin pisar sus cambios. Todo con el requisito de ligereza
(`AGENTS.md` § «Ligereza»): ningún punto se cierra si sube la memoria o la CPU en reposo sin motivo.

Las tandas 1 (diseño 2.1 y movimiento sobre labwc) y 2 (Ajustes, centro de control y barra
configurable) están hechas: `docs/DISENO.md` y `docs/notas/escritorio.md`.

### Tanda 3 — Animaciones de ventanas (Hyprland, a prueba)

7. **Sesión Hyprland de prueba** (Opus, alto: compositor nuevo con paridad). Se elige al iniciar
   sesión; labwc sigue de serie. Condición del usuario: **solo cambian las animaciones** (abrir,
   cerrar, minimizar y cambiar de escritorio con las curvas de la marca); lo demás se ve y se usa
   igual (flotantes, barras de título, menú del escritorio, Alt+Tab, atajos, escritorios). Riesgo:
   las apps sin cabecera propia (Thunar, kitty) necesitan `hyprbars`, que no está en Arch y se
   compila para cada versión. No se prueba en la VM (sin 3D): la prueba el usuario en su portátil.
   Si no llega a la paridad o pesa bastante más que labwc (memoria y CPU en reposo, medidas en el
   portátil), se queda labwc y se anota en `docs/decisiones.md`. Condiciones para
   adoptarla (que una actualización no lo rompa): `hyprbars` compilado por nosotros en el repositorio
   firmado y atado a la versión exacta de Hyprland, Hyprland solo cambia con la fecha validada de
   Arch, la CI comprueba plugin y configuración antes de publicar, y labwc queda como sesión de
   reserva. Si se adopta: Hyprland de serie y, si no arranca o se cierra al empezar,
   `command-os-session` arranca labwc solo y avisa (también en equipos sin aceleración 3D, como la
   VM); el selector de sesión queda discreto (inicio de sesión y Ajustes) para fallos que no la cierran.
   Estudio de paridad hecho (`docs/notas/escritorio.md` § «Sesión Hyprland de prueba»). Por partes:
   - 7.1 **Sesión y configuración** (Opus, alto: la base de todo lo demás). `command-os-session
     hyprland`, selector en el inicio de sesión, `hyprland.lua` (aspecto, atajos, reglas, animaciones,
     minimizar), `command-os-desktops` y recargas para Hyprland, y `--verify-config` en
     `tests/escritorio.sh`.
   - 7.2 **hyprbars propio** (Opus, alto: empaquetado, parche en C++ y CI). PKGBUILD atado a la
     versión de Hyprland, parche de botones cuadrados con hover, repositorio firmado y comprobación
     en la CI (con los minutos estimados antes).
   - 7.3 **Menús, Alt+Tab y encajar** (Opus, medio: piezas sueltas sobre la 7.1). Menú del escritorio
     y de ventana con wofi, Alt+Tab con rofi y encajar al soltar en el borde; guía de prueba en
     `docs/prueba-en-pc-real.md`.
8. **Barra que se oculta sola** (Opus, medio: depende del 7). Con Hyprland, Ironbar (en Arch, con
   ocultado nativo) o Waybar con un ayudante que mire el puntero (`hyprctl cursorpos`).
