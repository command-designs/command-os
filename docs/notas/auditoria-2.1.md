# Auditoría de fidelidad a la marca 2.1 (2026-10-20)

Punto 1 de la tanda «Diseño 2.1 y movimiento» (`ROADMAP.md`). Guía los puntos 3–4 (las ventanas, punto
2, ya están: `docs/notas/escritorio.md` § «Ventanas iguales», con sus límites): cada diferencia
lleva el punto que la resuelve. Cuando un punto se cierra, sus filas se borran de aquí; cuando no
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

## Barra (punto 3)

| # | Diferencia | Objetivo |
| --- | --- | --- |
| B1 | 30 px de alto; la referencia mide 3,5 em (56 px a 16 px). | Más aire sin comer pantalla: 36–40 px, con el logo en su celda cuadrada (4,25 em en la referencia). |
| B2 | Iconos a todo color (Papirus; Discord en azul), fijadas y ventanas iguales. | Como el carril de la referencia (`.a-rail`): apagados en reposo y a color en la ventana activa y al pasar el ratón; la activa en Slate con filo Steel y la línea Red Hot. GTK 3 no tiene filtro de gris: atenuar con opacidad. |
| B3 | Una caja con filo Steel por cada lectura (CPU, MEM, NET, VOL…): ocho celdas que compiten. | Un solo grupo de estado a la derecha, sin cajas internas, como la lectura «sincronizado» de la referencia; clic: centro de control (punto 5). CPU/TMP/MEM, opcionales (Ajustes). |
| B4 | La bandeja enseña el icono blanco relleno de nm-applet, fuera de estilo. | Desaparece con el centro de control (la red pasa al grupo de estado); la bandeja queda para apps de terceros. |

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
