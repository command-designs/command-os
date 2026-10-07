# Command OS — hoja de ruta

Por orden. Cuando algo se termina y se verifica, se quita de aquí (el detalle queda en `AGENTS.md`,
`docs/` y el historial de git). **Prioridad x86**: se trabaja y se prueba en x86; nada específico
de hardware ARM hasta saber qué placa lleva el cyberdeck (`AGENTS.md`).

12. **Instalador en inglés** (decidir antes). Corre en la ISO de Arch, antes de Command OS: habría que
   llevar los `.mo` dentro del paquete firmado y elegir el idioma a partir del de la ISO. La
   confirmación de borrado se teclea («Escribe SI…»): traducirla exige una prueba nueva en
   `tests/discos.sh` (`AGENTS.md`: no se relaja sin ella).
   Además, `configure_system` (`build/x86/lib.sh`) reescribe `GRUB_CMDLINE_LINUX` con solo
   `cryptdevice=`: tendrá que conservar `command-os.idioma=` (hoy da igual: instala en castellano).
   _Modelo y esfuerzo recomendados:_ Opus, esfuerzo alto (borrado de discos).

## Lo prueba el usuario

- PC real (bare metal x86, GPU NVIDIA).
- Instalar en un PC real con `instalar-command-os.sh` (dual boot o disco entero; `docs/instalacion.md` § 2):
  arranque desde la entrada UEFI, wifi y gráfica concretos.
- Disco cifrado en un PC real (`docs/cifrado.md`): la contraseña en el splash con el teclado del
  portátil y con uno USB, una contraseña con símbolos (en la VM solo se teclean letras, cifras y
  espacios) y el splash con gráfica NVIDIA.
- Escala automática en un portátil de alta densidad y con un segundo monitor conectado en marcha
  (`docs/notas/pantallas.md`; la VM no da tamaño físico).

## Aparcado hasta tener el hardware ARM del cyberdeck

- **Imagen ARM con btrfs** (antes punto 8): script de construcción para ARM (subvolúmenes, snapper,
  arranque de la placa que se elija) y validar los paquetes en aarch64, con la variante del cyberdeck
  (`os/variants/<v>/inicio-automatico-de-serie`: el asistente propone entrar sin contraseña). Se
  retoma cuando se sepa la placa; no tiene por qué ser una Raspberry Pi 5.

## Otros pendientes

- Probar en la VM lo configurado y no verificado: apagado de pantalla a los 10 min, portapapeles,
  teclas de volumen y brillo, clic derecho en el escritorio (no se simula sin ratón virtual).
- Oír los sonidos (solo se ha verificado que no saturan).
- Dual boot en un portátil real (entrada UEFI, BitLocker): `docs/dualboot.md`.
- Diseño del objeto y anclas 6–8 de la marca: dependen del hardware.
- Aviso de actualizaciones: un panel gráfico de actualización (hoy se abre `command-os-update` en una
  terminal; ver `docs/decisiones.md`) y comprobar en un equipo con instantáneas que el aviso cuenta bien
  tras volver atrás con `command-os-rollback`.
- Probar el asistente de primer arranque en varias resoluciones (VM `command-os-instalador`).
- Cuentas (fuera del punto del primer arranque, `docs/cuentas.md`): añadir y gestionar más cuentas
  desde el escritorio (con idioma propio de cada cuenta), zona horaria en el asistente y un panel para
  cambiar la contraseña y el idioma.
- Prueba automática de `command-os-rollback` (sin y con `/boot` aparte, y que deshace todo si falla):
  hoy solo se prueba a mano en la VM, porque el script actúa sobre la raíz del sistema en marcha.
- Disco cifrado (`docs/cifrado.md`): un panel para cambiar la contraseña del disco y la clave de
  recuperación (hoy, `cryptsetup` en una terminal) y, con el disco cifrado, que el asistente de primer
  arranque proponga entrar sin contraseña (para no escribir dos al encender).
