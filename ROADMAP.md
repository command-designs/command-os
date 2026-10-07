# Command OS — hoja de ruta

Por orden. Cuando algo se termina y se verifica, se quita de aquí (el detalle queda en `AGENTS.md`,
`docs/` y el historial de git). **Prioridad x86**: se trabaja y se prueba en x86; nada específico
de hardware ARM hasta saber qué placa lleva el cyberdeck (`AGENTS.md`).

7. **Command OS como sistema principal** (disco entero, sin Windows). Hoy hay imagen para grabar en
   USB (`build-image.sh`) y dual boot (`install-dualboot.sh`), pero no un instalador al disco interno
   del equipo. Un modo «disco entero» del instalador (borra el disco, con confirmación clara), y probar
   el recorrido completo en la VM: USB → instalar → primer arranque → actualizar.
   _Modelo y esfuerzo recomendados:_ Opus, esfuerzo alto (particiones y borrado de disco: un fallo es irreversible).

## Lo prueba el usuario

- PC real (bare metal x86, GPU NVIDIA).

## Aparcado hasta tener el hardware ARM del cyberdeck

- **Imagen ARM con btrfs** (antes punto 8): script de construcción para ARM (subvolúmenes, snapper,
  arranque de la placa que se elija) y validar los paquetes en aarch64, con la variante del cyberdeck
  (`os/variants/<v>/inicio-automatico-de-serie`: el asistente propone entrar sin contraseña). Se
  retoma cuando se sepa la placa; no tiene por qué ser una Raspberry Pi 5.

## Otros pendientes

- **Autorizar Context7** (`claude mcp list` lo marca «Needs authentication»): abrir `claude` en una
  terminal, `/mcp`, elegir `context7` y autenticar. Una sola vez, vale para todos los proyectos.
- Probar en la VM lo configurado y no verificado: apagado de pantalla a los 10 min, portapapeles,
  teclas de volumen y brillo, clic derecho en el escritorio (no se simula sin ratón virtual).
- Oír los sonidos (solo se ha verificado que no saturan).
- Dual boot en un portátil real (entrada UEFI, BitLocker): `docs/dualboot.md`.
- Diseño del objeto y anclas 6–8 de la marca: dependen del hardware.
- Aviso de actualizaciones: un panel gráfico de actualización (hoy se abre `command-os-update` en una
  terminal; ver `docs/decisiones.md`) y comprobar en un equipo con instantáneas que el aviso cuenta bien
  tras volver atrás con `command-os-rollback`.
- Cuentas (fuera del punto del primer arranque, `docs/cuentas.md`): cifrado de disco, añadir y
  gestionar más cuentas desde el escritorio, zona horaria en el asistente y un panel para cambiar la
  contraseña.
