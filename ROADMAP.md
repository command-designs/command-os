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

6. **Bluetooth** (`bluez`, panel o `blueman`, módulo en la barra, textos traducidos, prueba en
   `tests/escritorio.sh`). _Opus, esfuerzo medio (toca paquete, barra, idioma y marca)._
7. **Licencia del repo (público y sin licencia).** Decide el usuario: ninguna, permisiva (MIT/Apache-2.0)
   o copyleft (GPL-3.0). Aplicarla: _Sonnet, esfuerzo bajo._
8. **Ajustar el diseño de command-os al lenguaje HUD** (`lenguaje.html` de command-web y `BRAND.md` 2.1,
   en command-designs/command-web#8: plano holográfico, modo HUD, halo solo en la señal y en los LED,
   arranque con diagnóstico). Ojo: `tests/marca.sh` prohíbe hoy halos y `text-shadow`; la regla cambia
   con 2.1 y se ajusta primero. Revisar pieza a pieza (barra, menús, paneles, notificaciones, bloqueo,
   splash, GRUB, fondos, sonidos, apps GTK), anotar cada diferencia, corregirlas y dejar `tests/marca.sh`
   y `docs/DISENO.md` al día. _Opus, esfuerzo alto (toca tema, generadores y arranque; hay que comparar
   con el concepto en pantalla)._
