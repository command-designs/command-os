# Command OS — hoja de ruta

Por orden. Cuando algo se termina y se verifica, se quita de aquí (el detalle queda en `CLAUDE.md`,
`docs/` y el historial de git). Todo cambio vale a la vez para x86 (GRUB) y ARM/Pi 5 (`cmdline.txt`).

0. **Primera publicación del paquete.** La Release `repo` de `command-designs/command-os-versions`
   todavía no existe: revisar el error de la ejecución de `publicar` en Actions (o lanzarla a mano
   con Run workflow). Cuando salga, comprobar en la VM que `update` (`command-os-update`) añade el
   repositorio `[command-os]`, importa la clave y actualiza el paquete desde ahí.
   _Modelo y esfuerzo recomendados:_ Sonnet, esfuerzo bajo (es revisar un error de Actions; sube a medio si hay que tocar el flujo).
1. **Lista de instantáneas de GRUB al día tras un retroceso.** Tras `command-os-rollback`, el
   `grub-btrfs.cfg` del sistema recuperado está desfasado hasta la siguiente instantánea:
   regenerarlo en el primer arranque. Solo x86 (el Pi no tiene GRUB). Verificar en la VM btrfs.
   _Modelo y esfuerzo recomendados:_ Opus, esfuerzo medio (btrfs y GRUB: un fallo deja el equipo sin arrancar).
2. **Splash que se pueda saltar** con una tecla (Esc sigue siendo el modo detalles) y medir la
   duración real de la animación. Ancla 2 de `docs/DISENO.md`.
   _Modelo y esfuerzo recomendados:_ Sonnet, esfuerzo medio (script de Plymouth acotado).
3. **Pantalla «Acerca de CMD-OS»** con nombre y código, visible desde el escritorio. Ancla 5.
   Decidir antes formato y datos (versión del paquete, fecha de Arch validada, hardware…).
   _Modelo y esfuerzo recomendados:_ Sonnet, esfuerzo medio (pantalla pequeña; el diseño lo decides tú antes).
4. **Firefox personalizado**: página de inicio, tema y políticas de serie dentro del paquete.
   _Modelo y esfuerzo recomendados:_ Sonnet, esfuerzo medio (políticas y preferencias de Firefox).
5. **Instalador que pida usuario y contraseña** (hoy `deck`/`deck` fijo con inicio automático).
   Cambio grande: decidir antes asistente de primer arranque o pregunta al instalar, y si se
   mantiene el inicio automático.
   _Modelo y esfuerzo recomendados:_ Opus, esfuerzo alto (toca instalación, autologin y bloqueo en x86 y ARM).
6. **Imagen ARM con btrfs para la Pi 5.** No hay script de construcción para ARM todavía: crearlo
   (Arch Linux ARM, subvolúmenes, `rootflags=subvol=@` en `cmdline.txt`, snapper) y validar los
   paquetes en aarch64. Primero que se construya; el arranque, en la placa.
   _Modelo y esfuerzo recomendados:_ Opus, esfuerzo alto (script nuevo desde cero, sin placa para probar).

## Lo prueba el usuario

- PC real (bare metal x86, GPU NVIDIA) y la Pi 5 cuando esté.

## Otros pendientes

- Probar en la VM lo configurado y no verificado: apagado de pantalla a los 10 min, portapapeles,
  teclas de volumen y brillo, clic derecho en el escritorio (no se simula sin ratón virtual).
- Oír los sonidos (solo se ha verificado que no saturan).
- Dual boot en un portátil real (entrada UEFI, BitLocker): `docs/dualboot.md`.
- Diseño del objeto y anclas 6–8 de la marca: dependen del hardware.
