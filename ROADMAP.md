# Command OS — hoja de ruta

Por orden. Cuando algo se termina y se verifica, se quita de aquí (el detalle queda en `AGENTS.md`,
`docs/` y el historial de git). **Prioridad x86**: se trabaja y se prueba en x86; nada específico
de hardware ARM hasta saber qué placa lleva el cyberdeck (`AGENTS.md`).

## Lo prueba el usuario

- PC real (bare metal x86, GPU NVIDIA).
- Instalar en un PC real con `instalar-command-os.sh` (dual boot o disco entero; `docs/instalacion.md` § 2):
  arranque desde la entrada UEFI, wifi y gráfica concretos. Dual boot en un portátil real
  (`docs/dualboot.md`): la entrada UEFI y Windows con BitLocker.
- Oír los sonidos del sistema (en la VM solo se ha comprobado que no saturan).
- Teclas de brillo en un portátil real (la VM no tiene retroiluminación: solo se prueba que lanzan la orden).
- Disco cifrado en un PC real (`docs/cifrado.md`): la contraseña en el splash con el teclado del
  portátil y con uno USB, una contraseña con símbolos (en la VM solo se teclean letras, cifras y
  espacios) y el splash con gráfica NVIDIA.
- Hora en un dual boot con Windows de verdad (`docs/cuentas.md` § «Hora»): elegir otra zona en el
  asistente sin red y que Windows y Command OS sigan con la misma hora.
- Escala automática en un portátil de alta densidad y con un segundo monitor conectado en marcha
  (`docs/notas/pantallas.md`; la VM no da tamaño físico).

## Aparcado hasta tener el hardware ARM del cyberdeck

- **Imagen ARM con btrfs** (antes punto 8): script de construcción para ARM (subvolúmenes, snapper,
  arranque de la placa que se elija) y validar los paquetes en aarch64, con la variante del cyberdeck
  (`os/variants/<v>/inicio-automatico-de-serie`: el asistente propone entrar sin contraseña). Se
  retoma cuando se sepa la placa; no tiene por qué ser una Raspberry Pi 5.
- **Diseño del objeto y anclas 6–8 de la marca** (`docs/DISENO.md`): dependen del hardware.

## Pendientes (por orden)

1. Diseños (se plantean y esperan el visto bueno antes de escribir código). *Opus, alto.*
   - Cuentas (`docs/cuentas.md`): añadir y gestionar más cuentas desde el escritorio (con idioma propio
     de cada cuenta) y un panel para cambiar la contraseña, el idioma y la zona horaria.
   - Disco cifrado (`docs/cifrado.md`): un panel para cambiar la contraseña del disco y la clave de
     recuperación (hoy, `cryptsetup` en una terminal).
   - Aviso de actualizaciones: un panel gráfico de actualización (hoy se abre `command-os-update` en
     una terminal; ver `docs/decisiones.md`).
