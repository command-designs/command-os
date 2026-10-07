# Command OS — hoja de ruta

Por orden. Cuando algo se termina y se verifica, se quita de aquí (el detalle queda en `AGENTS.md`,
`docs/` y el historial de git). Todo cambio vale a la vez para x86 (GRUB) y ARM/Pi 5 (`cmdline.txt`).

6. **Aviso de actualizaciones en el escritorio.** Hoy solo se actualiza con `update` en una terminal.
   Comprobar en segundo plano (temporizador de systemd, sin tocar el sistema) si hay versión nueva de
   `command-os` o de Arch, enseñarlo en la barra (Waybar) y, al pulsarlo, actualizar con
   `command-os-update` en una terminal o un panel. Decidir antes: cada cuánto se mira y si se avisa
   también con una notificación.
   _Modelo y esfuerzo recomendados:_ Sonnet, esfuerzo medio (módulo de Waybar y un temporizador).
7. **Command OS como sistema principal** (disco entero, sin Windows). Hoy hay imagen para grabar en
   USB (`build-image.sh`) y dual boot (`install-dualboot.sh`), pero no un instalador al disco interno
   del equipo. Un modo «disco entero» del instalador (borra el disco, con confirmación clara), y probar
   el recorrido completo en la VM: USB → instalar → primer arranque → actualizar.
   _Modelo y esfuerzo recomendados:_ Opus, esfuerzo alto (particiones y borrado de disco: un fallo es irreversible).
8. **Imagen ARM con btrfs para la Pi 5.** No hay script de construcción para ARM todavía: crearlo
   (Arch Linux ARM, subvolúmenes, `rootflags=subvol=@` en `cmdline.txt`, snapper) y validar los
   paquetes en aarch64. Primero que se construya; el arranque, en la placa. Con la variante del
   cyberdeck (`os/variants/<v>/inicio-automatico-de-serie`: el asistente propone entrar sin contraseña).
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
- Cuentas (fuera del punto del primer arranque, `docs/cuentas.md`): cifrado de disco, añadir y
  gestionar más cuentas desde el escritorio, zona horaria en el asistente y un panel para cambiar la
  contraseña.
