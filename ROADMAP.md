# Command OS — hoja de ruta

Por orden. Cuando algo se termina y se verifica, se quita de aquí (el detalle queda en `AGENTS.md`,
`docs/` y el historial de git). **Prioridad x86**: se trabaja y se prueba en x86; nada específico
de hardware ARM hasta saber qué placa lleva el cyberdeck (`AGENTS.md`).

## Lo prueba el usuario

- PC real (bare metal x86, GPU NVIDIA).
- Instalar en un PC real con `instalar-command-os.sh` (dual boot o disco entero; `docs/instalacion.md` § 2):
  arranque desde la entrada UEFI, wifi y gráfica concretos. Dual boot en un portátil real
  (`docs/dualboot.md`): la entrada UEFI y Windows con BitLocker.
- Oír los sonidos del sistema de la marca v2 en un PC real (`docs/DISENO.md` § «Sonido»; los prototipos
  se escucharon aparte, en el sistema solo se ha comprobado que no saturan).
- Teclas de brillo en un portátil real (la VM no tiene retroiluminación: solo se prueba que lanzan la orden).
- Disco cifrado en un PC real (`docs/cifrado.md`): la contraseña en el splash con el teclado del
  portátil y con uno USB, una contraseña con símbolos (en la VM solo se teclean letras, cifras y
  espacios) y el splash con gráfica NVIDIA.
- Paneles de actualizaciones, cuentas y disco cifrado (menú → ajustes) en un PC real: el diálogo de
  polkit y, con el disco cifrado, cambiar la contraseña y la clave de recuperación y **reiniciar** para
  comprobar que el splash pide la nueva y que la clave vieja ya no entra (en la VM cifrada, con
  `gestionar-disco` a mano, ya arrancan la contraseña y la clave nuevas y las viejas se rechazan; falta
  el diálogo de polkit y el panel con el ratón).
- Hora en un dual boot con Windows de verdad (`docs/cuentas.md` § «Hora»): elegir otra zona en el
  asistente sin red y que Windows y Command OS sigan con la misma hora.
- Batería en un portátil real (`docs/notas/escritorio.md` § «Batería»; la VM no tiene batería): los
  avisos al 20 % y al 10 % y, si el panel de la batería (clic derecho en `bat`) enseña «limitar la
  carga al 80 %», que el portátil deje de cargar ahí y que siga limitado tras reiniciar y tras el reposo.
- Aplicaciones fijadas con el ratón de verdad (en la VM se probaron las órdenes de cada clic): clic
  para abrir, clic derecho en una fijada (quitar, mover) y clic derecho en el logo para fijar otra.
- Escala automática en un portátil de alta densidad y con un segundo monitor conectado en marcha
  (`docs/notas/pantallas.md`; la VM no da tamaño físico).
- Instalar aplicaciones en un PC real (`docs/notas/escritorio.md` § «Instalar aplicaciones»; en la VM
  se instaló y abrió Discord): instalar algo desde la tienda (la fijada de la barra o menú → tienda de
  aplicaciones) y abrirlo desde el lanzador; descargar un `.tar.gz` o `.zip` con Firefox y abrirlo con
  **doble clic** en Thunar (xarchiver, sin preguntar) y extraerlo con el clic derecho; abrir un AppImage
  de verdad y un `.deb` descargados; que una app GTK de Flathub se vea oscura y con el filo rojo. Con una
  app con versión nueva, que `upd` la cuente y el panel la liste en «aplicaciones de la tienda», y que
  tras `update` (o actualizarla desde la tienda) deje de contarla (`docs/actualizaciones.md` § 7; en
  un Arch desechable se probó la comprobación con Flatpak de verdad, no la barra en pantalla). En una
  instalación nueva, que `findmnt /var/lib/flatpak` salga de `@flatpak` y que, tras volver atrás con
  `command-os-rollback`, las apps instaladas después de la instantánea sigan ahí (`docs/actualizaciones.md`
  § 5; en disco loop lo cubre `tests/rollback.sh`).
- Forma de la marca v2 en un PC real (`docs/DISENO.md` § «Forma»): chaflanes en el menú del clic
  derecho de Thunar y Firefox, en sus diálogos (botones), en las notificaciones y en una app GTK 3 de
  Flathub; y cómo se ven a alta densidad (en la VM, a escala 2, el filo sale algo suave).
- Arranque de la marca v2 en un PC real (`docs/DISENO.md` § «Movimiento»): la firma (el símbolo se traza
  y se rellena, su barra, el wordmark) y que una tecla la salte; la lista de comprobaciones con los
  estados de tu equipo y el medidor; el menú de GRUB con el chaflán (Esc al encender); y, con el disco
  cifrado, la contraseña en el sitio de la lista y «disco del sistema» en curso al abrirlo (en la VM
  cifrada el splash v2 con el campo de contraseña en el sitio de la lista ya se vio el 2026-10-20; falta
  «disco del sistema» en curso y el medidor).

## Aparcado hasta tener el hardware ARM del cyberdeck

- **Imagen ARM con btrfs** (antes punto 8): script de construcción para ARM (subvolúmenes, snapper,
  arranque de la placa que se elija) y validar los paquetes en aarch64, con la variante del cyberdeck
  (`os/variants/<v>/inicio-automatico-de-serie`: el asistente propone entrar sin contraseña). Se
  retoma cuando se sepa la placa; no tiene por qué ser una Raspberry Pi 5.
- **Diseño del objeto y anclas 6–8 de la marca** (`docs/DISENO.md`): dependen del hardware.

## Pendientes (por orden)

Los puntos 1–3 van juntos en la rama actual y en un solo PR; los 4 y 5, en ese PR o el siguiente.

1. **CI en verde.** Arreglar tres fallos: `os/lib/reglas.sh` sin línea `# shellcheck shell=bash` (SC2148);
   `tests/discos.sh` lanza `gestionar-disco` sin `bash` y `os/lib` no tiene permiso de ejecución en git;
   el grep de `tests/cuentas.sh` (§ «Reglas de las cuentas») busca `\]\[^$]` y debe ser `\][^$]`. Reintentos
   de pacman contra archive.archlinux.org («Operation too slow»). Recortar `pruebas.yml` (`push` solo a
   `main` más `pull_request`) y poner `timeout-minutes` y `concurrency` en todos los workflows. Después,
   abrir el PR de la rama. _Sonnet, esfuerzo medio._
2. **Avisar cuando falle la CI programada.** Que el fallo diario de «escritorio con el Arch del día» abra
   o actualice un issue (desde el 2026-10-16 fallaba sin que nadie lo viera). _Sonnet, esfuerzo bajo._
3. **Pruebas en WSL como en la CI.** `build/wsl/pruebas.sh`: lanza en el Arch de WSL las mismas pruebas
   que la CI, para no dar por comprobado lo que solo corrió en parte. _Sonnet, esfuerzo medio._
4. **Guía de prueba en un PC real.** Convertir «Lo prueba el usuario» en `docs/prueba-en-pc-real.md`
   (lista ordenada que sigue una sola instalación); aquí queda un enlace. _Sonnet, esfuerzo bajo._
5. **`AGENTS.md` más corto** (197 líneas, la 30 tiene 705 caracteres): partir esa línea y llevar a `docs/`
   la historia de QEMU/Packer y lo de la VM vieja. _Sonnet, esfuerzo bajo._
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
