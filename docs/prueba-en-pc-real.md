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

## 3. Arranque y aspecto de `lenguaje.html` (`docs/DISENO.md` § «Movimiento»)

1. La firma (el símbolo se traza y se rellena, su barra, el wordmark), el paso del símbolo al anillo y
   que una tecla la salte.
2. La lista de comprobaciones con los estados de tu equipo, el anillo, la barra y un consejo distinto
   en cada arranque.
3. El menú de GRUB con el chaflán (Esc al encender): las entradas en Geist y los rótulos en mono
   mayúsculas se leen bien a la resolución de tu pantalla (en la VM, a 1024x768, sí).
4. A ritmo real (la VM va por software): el LED de la barra con su halo, el hover de los botones de las
   apps (filo Red Hot; el principal, más oscuro) y la entrada del bloqueo.
5. Con el disco cifrado: la contraseña en el sitio de la lista y «disco del sistema» en curso al abrirlo
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
7. Bluetooth (`docs/notas/escritorio.md` § «Bluetooth»; la VM no tiene adaptador): `bt off` en la barra
   al arrancar; clic derecho lo enciende (`bt on`) y otro lo apaga; clic → «bluetooth» en el panel de
   estado abre los dispositivos bajo la barra y otro clic los cierra. Emparejar unos auriculares y un teclado (si pide PIN, que salga el
   diálogo), ver `bt 1` y su nombre al pasar el ratón, oír el sonido por los auriculares y, tras
   reiniciar, que vuelva a salir `bt off`.
8. Ventanas iguales (`docs/notas/escritorio.md` § «Ventanas iguales»), tras actualizar sin reinstalar:
   Thunar, la tienda y Firefox con la misma barra de título (alto, botones, Graphite activa y Void
   inactiva); pasar el ratón por los botones de la tienda (Bone sobre Steel, cerrar en Signal Red) y
   maximizarla (el botón cambia a dos marcos); Firefox con sus pestañas cuadradas, la línea roja en la
   activa, página nueva sin patrocinados ni el tiempo y sin el botón de VPN; y una app Flatpak GTK 4 con
   los mismos botones.
9. Barra 2.1 (`docs/notas/escritorio.md` § «Barra»), tras actualizar sin reinstalar: sin el icono de la
   red en la bandeja; pasar el ratón por el grupo de estado (se ilumina entero) y clic (panel bajo la
   barra con wi-fi, bluetooth, sonido, batería y telemetría). Wi-Fi (la VM no tiene): clic derecho en
   `NET` → la lista de redes; conectar a una abierta, a una con contraseña (sale el diálogo y conecta),
   a una ya guardada (sin preguntar), escribir mal una contraseña (avisa de que no pudo) y desconectar
   la conectada. Enseñar y ocultar CPU/TMP/MEM desde el panel y que se mantenga al reiniciar.
10. Movimiento (`docs/DISENO.md` § «Movimiento»; la VM renderiza por software y no sirve para juzgar la
    fluidez): al cambiar de ventana, la línea roja de la barra entra por la izquierda y la anterior se va
    por la derecha; al pasar el ratón por botones, filas y campos de Thunar, Firefox y la tienda, el
    color cambia suave (no de golpe) y sin tirones; una notificación (`notify-send hola`) entra con un
    desliz corto; el panel del inicio de sesión entra con un fundido. Nada debe moverse con el
    escritorio en reposo (`top`: Waybar y labwc cerca del 0 % de CPU).
11. Ajustes y centro de control (`docs/notas/escritorio.md` § «Ajustes y centro de control»), con
    wi-fi, Bluetooth, brillo y batería de verdad (la VM no tiene): el clic en el grupo de estado abre
    el centro bajo la barra, a la derecha, con el desliz de 280 ms; **un clic fuera (en el escritorio,
    en otra ventana o en la barra), Escape o el mismo clic en la barra lo cierran**, y al cerrarlo no
    queda ningún proceso (`pgrep -f command-os-centro`). Wi-Fi: el interruptor enciende y apaga; la
    flecha (o clic derecho en `NET`) lista las redes; conectar a una abierta, a una con contraseña
    (se pide en el propio panel), a una guardada y escribir mal la contraseña. Bluetooth: el
    interruptor y la flecha (emparejar abre blueman). Volumen y brillo con el deslizador y que sigan
    a las teclas; la batería con su porcentaje y el estado de carga. Ajustes (menú → ajustes), cada
    sección: que lo cambiado se mantenga al reiniciar. Y que `lstopo`, `btop` y
    `Advanced Network Configuration` ya no salgan en el lanzador.
12. Barra configurable (`docs/notas/escritorio.md` § «Barra»), en Ajustes → Barra: cada lado (arriba,
    abajo, izquierda y derecha) y «flotante», con el ratón y en la pantalla del portátil. La barra
    cambia al momento, sin cerrar la sesión, y las ventanas maximizadas no quedan debajo de ella. A un
    lado: lecturas en dos líneas, la línea roja de la ventana activa en el borde de dentro y la batería
    con su porcentaje. El centro de control cuelga junto al grupo de estado en cada lado (abajo a la
    derecha con la barra abajo o a la derecha, abajo a la izquierda con la barra a la izquierda). **Con
    la barra abajo y wi-fi de verdad (la VM no tiene)**: la flecha a las redes abre el panel otra vez,
    entero en la pantalla, y la lista no crece hacia abajo al buscar ni al pedir la contraseña. Que el
    lado elegido se mantenga al reiniciar.

## 6. Ajustes (menú → ajustes)

1. Secciones de actualizaciones, cuentas y disco cifrado: el diálogo de polkit.
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
