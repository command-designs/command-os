# Guía de prueba en un PC real

Lista ordenada que sigue **una sola instalación** en un PC real (bare metal x86, GPU NVIDIA). Lo que
aquí figura no se puede comprobar en la VM; lo que sí se probó allí se indica en cada punto. Marca cada
punto al probarlo y avisa de los fallos; lo que salga bien se quita de esta guía.

## 1. Antes de instalar

- Dual boot en un portátil con Windows y BitLocker: ten a mano la clave de recuperación (`docs/dualboot.md`).
- Decide si el disco va cifrado (`docs/cifrado.md`); conviene probar las dos variantes si hay ocasión.

## 2. Instalación y primer arranque

1. Instalar con `instalar-command-os.sh` (dual boot o disco entero; `docs/instalacion.md` § 2): arranque
   desde la entrada UEFI, wifi y gráfica concretos.
2. Dual boot: la entrada UEFI y que Windows siga arrancando (con BitLocker).
3. Hora (`docs/cuentas.md` § «Hora»): elegir otra zona en el asistente sin red y que Windows y
   Command OS sigan con la misma hora.
4. Instalación nueva: `findmnt /var/lib/flatpak` sale de `@flatpak`.

## 3. Arranque de la marca v2 (`docs/DISENO.md` § «Movimiento»)

1. La firma (el símbolo se traza y se rellena, su barra, el wordmark) y que una tecla la salte.
2. La lista de comprobaciones con los estados de tu equipo y el medidor.
3. El menú de GRUB con el chaflán (Esc al encender).
4. Con el disco cifrado: la contraseña en el sitio de la lista y «disco del sistema» en curso al abrirlo
   (en la VM cifrada el splash v2 con el campo de contraseña ya se vio el 2026-10-20; faltan
   «disco del sistema» en curso y el medidor).

## 4. Disco cifrado (`docs/cifrado.md`)

1. La contraseña en el splash con el teclado del portátil y con uno USB.
2. Una contraseña con símbolos (en la VM solo se teclean letras, cifras y espacios).
3. El splash con gráfica NVIDIA.

## 5. Escritorio

1. Escala automática en un portátil de alta densidad y con un segundo monitor conectado en marcha
   (`docs/notas/pantallas.md`; la VM no da tamaño físico).
2. Teclas de brillo (la VM no tiene retroiluminación: solo se prueba que lanzan la orden).
3. Sonidos del sistema de la marca v2 (`docs/DISENO.md` § «Sonido»; en el sistema solo se ha comprobado
   que no saturan).
4. Forma de la marca v2 (`docs/DISENO.md` § «Forma»): chaflanes en el menú del clic derecho de Thunar y
   Firefox, en sus diálogos (botones), en las notificaciones y en una app GTK 3 de Flathub; y cómo se ven
   a alta densidad (en la VM, a escala 2, el filo sale algo suave).
5. Aplicaciones fijadas con el ratón de verdad (en la VM se probaron las órdenes de cada clic): clic para
   abrir, clic derecho en una fijada (quitar, mover) y clic derecho en el logo para fijar otra.
6. Batería (`docs/notas/escritorio.md` § «Batería»; la VM no tiene): avisos al 20 % y al 10 % y, si el
   panel de la batería (clic derecho en `bat`) enseña «limitar la carga al 80 %», que el portátil deje de
   cargar ahí y siga limitado tras reiniciar y tras el reposo.

## 6. Paneles de ajustes (menú → ajustes)

1. Paneles de actualizaciones, cuentas y disco cifrado: el diálogo de polkit.
2. Con el disco cifrado: cambiar la contraseña y la clave de recuperación y **reiniciar**; el splash pide
   la nueva y la clave vieja ya no entra (en la VM cifrada, con `gestionar-disco` a mano, ya funciona;
   falta el diálogo de polkit y el panel con el ratón).

## 7. Aplicaciones (`docs/notas/escritorio.md` § «Instalar aplicaciones»)

En la VM se instaló y abrió Discord.

1. Instalar algo desde la tienda (la fijada de la barra o menú → tienda de aplicaciones) y abrirlo desde
   el lanzador.
2. Descargar un `.tar.gz` o `.zip` con Firefox y abrirlo con **doble clic** en Thunar (xarchiver, sin
   preguntar) y extraerlo con el clic derecho.
3. Abrir un AppImage de verdad y un `.deb` descargados.
4. Una app GTK de Flathub se ve oscura y con el filo rojo.

## 8. Actualizaciones y vuelta atrás (`docs/actualizaciones.md`)

1. Con una app con versión nueva: `upd` la cuenta y el panel la lista en «aplicaciones de la tienda»; tras
   `update` (o actualizarla desde la tienda) deja de contarla (§ 7; en un Arch desechable se probó la
   comprobación con Flatpak de verdad, no la barra en pantalla).
2. Tras volver atrás con `command-os-rollback`, las apps instaladas después de la instantánea siguen ahí
   (§ 5; en disco loop lo cubre `tests/rollback.sh`).
