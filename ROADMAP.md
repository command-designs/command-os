# Command OS — hoja de ruta

Por orden. Cuando algo se termina y se verifica, se quita de aquí (el detalle queda en `AGENTS.md`,
`docs/` y el historial de git). Todo cambio vale a la vez para x86 (GRUB) y ARM/Pi 5 (`cmdline.txt`).

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

- **Autorizar Context7** (`claude mcp list` lo marca «Needs authentication»): abrir `claude` en una
  terminal, `/mcp`, elegir `context7` y autenticar. Una sola vez, vale para todos los proyectos.
- Probar en la VM lo configurado y no verificado: apagado de pantalla a los 10 min, portapapeles,
  teclas de volumen y brillo, clic derecho en el escritorio (no se simula sin ratón virtual).
- Oír los sonidos (solo se ha verificado que no saturan).
- Dual boot en un portátil real (entrada UEFI, BitLocker): `docs/dualboot.md`.
- Diseño del objeto y anclas 6–8 de la marca: dependen del hardware.
