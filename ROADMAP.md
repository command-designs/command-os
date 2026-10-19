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
- Paneles de actualizaciones, cuentas y disco cifrado (menú → ajustes) en un PC real: el diálogo de
  polkit y, con el disco cifrado, cambiar la contraseña y la clave de recuperación y **reiniciar** para
  comprobar que el splash pide la nueva (en la VM cifrada se comprobó que la contraseña nueva y la clave
  nueva abren el disco, pero no el arranque con ellas) y que la clave vieja ya no entra.
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
  de verdad y un `.deb` descargados; que una app GTK de Flathub se vea oscura y con el filo rojo.
- Forma de la marca v2 en un PC real (`docs/DISENO.md` § «Pantalla»): chaflanes en el menú del clic
  derecho de Thunar y Firefox, en sus diálogos (botones), en las notificaciones y en una app GTK 3 de
  Flathub; y cómo se ven a alta densidad (en la VM, a escala 2, el filo sale algo suave).
- Arranque de la marca v2 en un PC real (`docs/DISENO.md` § «Movimiento»): la firma (el símbolo se traza
  y se rellena, su barra, el wordmark) y que una tecla la salte; la lista de comprobaciones con los
  estados de tu equipo y el medidor; el menú de GRUB con el chaflán (Esc al encender); y, con el disco
  cifrado, la contraseña en el sitio de la lista y «disco del sistema» en curso al abrirlo (en la VM
  cifrada no se ha probado este arranque nuevo).

## Aparcado hasta tener el hardware ARM del cyberdeck

- **Imagen ARM con btrfs** (antes punto 8): script de construcción para ARM (subvolúmenes, snapper,
  arranque de la placa que se elija) y validar los paquetes en aarch64, con la variante del cyberdeck
  (`os/variants/<v>/inicio-automatico-de-serie`: el asistente propone entrar sin contraseña). Se
  retoma cuando se sepa la placa; no tiene por qué ser una Raspberry Pi 5.
- **Diseño del objeto y anclas 6–8 de la marca** (`docs/DISENO.md`): dependen del hardware.

## Pendientes (por orden)

El punto 1 termina de aplicar la identidad de marca v2 de command-web (`BRAND.md` 2.0 §§ 3–9 y
12.3, referencia `lenguaje.html`), que ya vale para Command OS y sustituye la estética HUD/Cyberpunk.
Colores, letra, forma (chaflanes y escuadras), fondos y arranque (firma, comprobaciones y GRUB) ya están
(con `tests/marca.sh`). Va en la rama `feat/identidad-de-marca-v2` y en un solo PR al terminarlo. Al
acabar no puede quedar nada del estilo Cyberpunk: todo pasa a la v2.
Antes de empezar: decir modelo y esfuerzo y esperar el «adelante» del usuario.

1. **Marca v2 — sonidos** (`build/make-sounds.py`): que suenen como la interfaz v2, un instrumento
   preciso y sobrio, en vez del aparato de Cyberpunk (golpe de encendido con ventiladores, alarma
   saturada). Antes de generar, proponer la dirección y que el usuario la escuche. Cierre de la marca
   v2: repaso de todo el repo («cyberpunk», «HUD», «2077», «glitch», «cian» y los hex viejos; en las
   notas históricas solo como historia), `tests/marca.sh` que falle si `TEMPORALES` no está vacía o
   si esas palabras vuelven a `os/` o `build/`, `DISENO.md` reescrito entero y PR. *Opus, medio:
   síntesis de sonido y repaso de muchos archivos.*

2. Reducir el gasto de la CI: `push` solo en `main`, los trabajos pesados (contenedor Arch) solo en PR y
   en la ejecución diaria, y caché de paquetes. Antes, arreglar la facturación de GitHub (los trabajos
   no arrancan: «recent account payments have failed»). *Sonnet, medio.*
3. Probar en la VM cifrada (`command-os-instalador`, con instantánea) el **arranque** con la contraseña
   y la clave de recuperación nuevas tras cambiarlas con el panel del disco, y que la vieja ya no
   entra. *Sonnet, medio.*
4. Limpieza de los paneles (`lib/panel-*.py`, `abrir-descarga.py`, `comun.py`): una clase base con
   `tecla`, `limpiar` y `en_hilo`, una sola copia de las reglas de contraseña y de nombre de usuario (hoy
   en bash y Python, cinco sitios) y reutilizar el selector de zona entre repintados. *Sonnet, medio.*
5. Que el aviso de actualizaciones de la barra y su panel cuenten también las apps de la tienda
   (Flatpak), sin tocar `/var/lib/flatpak` desde la comprobación de solo lectura (`docs/decisiones.md`,
   2026-10-19). *Opus, medio: toca la unidad de systemd, la barra y el panel.*
6. Subvolumen `@flatpak` en las instalaciones nuevas, para que las apps de la tienda no engorden las
   instantáneas de `@` (`build/x86/lib.sh`, `tests/rollback.sh`, `docs/actualizaciones.md` § 5). *Opus,
   alto: toca el instalador y la vuelta atrás.*
