# Auditoría de fidelidad a la marca 2.1 (2026-10-20)

Punto 1 de la tanda «Diseño 2.1 y movimiento» (`ROADMAP.md`). Guía el punto 4 (ya están las ventanas,
punto 2, y la barra, punto 3: `docs/notas/escritorio.md` §§ «Ventanas iguales» y «Barra», con sus
límites): cada diferencia lleva el punto que la resuelve. Cuando un punto se cierra, sus filas se borran de aquí; cuando no
quede ninguna, se borra el archivo (lo que valga para siempre pasa a `docs/DISENO.md`).

**Cómo se hizo:** VM `command-os-x86` a 1280×720 con el paquete de la rama (2026.10.20.1808), capturas
del inicio de sesión, el escritorio, Firefox, Thunar, Bazaar, kitty, el lanzador y una notificación,
frente a `lenguaje.html` § 03 (app en modo HUD, medidas en su CSS: `.a-top`, `.a-rail`, `.chip`,
`.palette`) y BRAND §§ 7–9.

## Ya está bien (no se toca)

- Inicio de sesión y asistente: panel con chaflán, escuadras, campo con foco Red Hot, botón principal.
- Lanzador: es la paleta de la referencia (lupa Red Hot, línea Steel, activo en Slate con barra Red Hot).
- Notificaciones: panel con chaflán, título en Bone y cuerpo en Ash.
- Fondo, prompt de kitty, colores de la paleta en todas partes (`tests/marca.sh`).

## Movimiento (punto 4)

| # | Diferencia | Objetivo |
| --- | --- | --- |
| M1 | Las hojas GTK 3/4, swaync y el inicio de sesión no tienen ninguna transición: el hover y el foco cambian de golpe. | Transiciones de color y filo de 160–280 ms con `--ease-out` en botones, filas, campos y pestañas (BRAND § 9.2.4); en GTK 4, el barrido del botón principal. |
| M2 | wofi usa la curva de Material (`0.4, 0, 0.2, 1`) en el hover. | Solo las curvas de la marca: `--ease-out`, `--ease-in-out` y `--ease-snap`. |
| M3 | Las notificaciones aparecen y se van sin movimiento. | Entrada con desliz corto y fundido (280 ms, `--ease-out`), salida con `--ease-in-out`. |
| M4 | La barra no anima el cambio de ventana activa ni el aviso de actualización. | La línea Red Hot del activo entra por la izquierda (subrayado de § 9.2.3); el LED aparece con fundido. |
| M5 | Las ventanas se abren y cierran sin animación. | No se puede con labwc: tanda 3 (Hyprland, a prueba). |

## Fuera de la tanda 1 (van a la tanda 2)

- El lanzador enseña herramientas técnicas al mismo nivel que las apps (`Hardware Locality lstopo`,
  `Advanced Network Configuration`, `Displays`, `btop++`): ocultarlas del lanzador y llevarlas a
  «avanzado» en Ajustes (punto 5).
