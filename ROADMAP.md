# Command OS — hoja de ruta

Por orden. Cuando algo se termina y se verifica, se quita de aquí (el detalle queda en `AGENTS.md`,
`docs/` y el historial de git). **Prioridad x86**: se trabaja y se prueba en x86; nada específico
de hardware ARM hasta saber qué placa lleva el cyberdeck (`AGENTS.md`).

8. **Pantallas 16:9 y 16:10 perfectas** (petición del usuario). Que todo se vea bien y sin recortes
   raros en 16:9 (1920x1080, 1366x768, 2560x1440) y 16:10 (1920x1200, 1280x800, 2560x1600): fondo de
   escritorio (hoy en 4:3 corta el logo por la derecha), splash de arranque, asistente de primer
   arranque, pantalla de inicio de sesión, bloqueo, barra, menús y escalado en pantallas de alta
   densidad. Probar cada resolución en la VM (`VBoxManage controlvm … setvideomodehint`) con capturas.
   _Modelo y esfuerzo recomendados:_ Opus, esfuerzo medio (varias piezas visuales y criterio de diseño).
9. **Cifrado de disco** (LUKS) al instalar en disco entero y en dual boot, con la contraseña dentro del
   splash y compatible con las instantáneas (grub-btrfs).
   _Modelo y esfuerzo recomendados:_ Opus, esfuerzo alto (arranque e initramfs; un fallo deja el equipo sin arrancar).
10. **Instalar sin clonar el repositorio privado.** Hoy hace falta un token de GitHub en el USB. Publicar
   el instalador firmado junto al paquete (`command-os-versions`) para bajarlo con `curl` y verificar su
   firma. **Decide el usuario antes:** hace públicos los scripts de instalación.
   _Modelo y esfuerzo recomendados:_ Opus, esfuerzo medio (publicación y firma).

## Lo prueba el usuario

- PC real (bare metal x86, GPU NVIDIA).
- Instalar en un PC real con `build/x86/instalar.sh` (dual boot o disco entero; `docs/instalacion.md`):
  arranque desde la entrada UEFI, wifi y gráfica concretos.

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
