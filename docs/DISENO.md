# Command OS — Lenguaje del producto

Cómo se ve y se mueve Command OS (`CMD-OS`). Es el sistema de un dispositivo, así que su interfaz es
propia; lo une a Command el cumplimiento de las anclas de `BRAND.md` § 12 (tabla al final).
Fuente de la marca: <https://github.com/command-designs/command-web> (`BRAND.md`, `tokens.css`).

## Idea

Un escritorio de terminal: casi monocromo, denso y sin adornos. El rojo es una señal, no decoración;
solo marca lo que está activo.

## Pantalla

- **Paleta** (de `tokens.css`): Void `#0E0E0E` fondo · Graphite `#151515` / Slate `#1F1F1F` superficies ·
  Steel `#2A2A2A` bordes · Bone `#EDEBE6` texto · Ash `#A3A09A` texto secundario · Red Hot `#F5482C`
  foco y activo · Signal Red `#A51500` barra del logo. Los colores están escritos a mano en cada
  dotfile (Hyprland, Waybar, Wofi, Mako, Hyprlock, Kitty, Alacritty); si cambia la marca hay que
  actualizarlos todos.
- **Tipografía:** JetBrains Mono en barra y terminal; Geist en lanzador y notificaciones; Oxanium en la
  hora del bloqueo. Oxanium y Geist no están en los repos de Arch y se instalan desde
  `os/branding/fonts/` (licencia OFL incluida).
- **Forma:** radios de 4 px, bordes de 1 px en vez de sombras, sin blur ni transparencias.
- **Fondo:** Void con matriz de puntos de 26 px y el wordmark atenuado (`build/make-wallpaper.py`).

## Movimiento

Curva `cubic-bezier(0.16, 1, 0.3, 1)` (`--ease-out`), 300–400 ms, sin rebotes.
**Firma de arranque:** el wordmark se revela de izquierda a derecha y después la barra roja se extiende
desde la izquierda, ~1,1 s (`os/branding/plymouth/`, fotogramas con `build/make-plymouth.py`).

## Sonido

Pendiente.

## Objeto

Pendiente: depende de la carcasa del hardware.

## Voz

Español, tuteo, minúsculas y tono terminal: `› bloqueado`, `contraseña`, `sin red`. Sin exclamaciones
ni emojis.

## Anclas de Command

| #   | Ancla                      | Cómo se cumple                                                                                                                    | Estado                                       |
| --- | -------------------------- | --------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------- |
| 1   | Logotipo con su barra      | Símbolo C en Waybar y bloqueo; wordmark en el splash y en el fondo; siempre con la barra roja.                                    | ✔ verificado en VM                           |
| 2   | Firma de arranque          | Plymouth: letras de izquierda a derecha y luego la barra. ~1,1 s. **Saltable con una tecla: no implementado.**                    | parcial (splash visto; animación sin medir)  |
| 3   | Un solo punto rojo         | En pantalla el rojo solo marca lo activo (borde de ventana, espacio de trabajo, foco). El punto rojo físico depende del hardware. | pantalla ✔ · objeto pendiente                |
| 4   | Voz                        | Textos de bloqueo, `issue` y `motd` en tono terminal.                                                                             | ✔                                            |
| 5   | Nombre y código            | `os-release` (`VARIANT="CMD-OS"`), `/etc/issue` y `motd`. Falta una pantalla de información del sistema.                           | parcial                                      |
| 6   | Principios como requisitos | Base abierta (Arch + dotfiles en el repo). Resto depende del hardware.                                                            | pendiente                                    |
| 7   | Por dentro también         | Serigrafía de la placa.                                                                                                           | pendiente (hardware)                         |
| 8   | Lo impreso es de la marca  | Caja, manuales, etiquetas.                                                                                                        | pendiente                                    |

## No hacer

- Recolorear la barra del logo ni ponerlo sobre fondos con ruido.
- Neones cian o magenta, degradados, blur o glassmorphism.
- Rojo repartido como decoración.
