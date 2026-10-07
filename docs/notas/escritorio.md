# Notas: escritorio labwc, rediseño, energía y sonido

Detalle movido de `CLAUDE.md` sin cambios (2026-10-06). Lenguaje visual: `docs/DISENO.md`.

## Escritorio labwc (2026-10-05)

- **Por qué**: producto para clientes que tiene que gustar a la mayoría y ser muy ligero. labwc es
  flotante (barra de título, botones, barra de tareas, Alt+Tab, clic derecho, Super abre el
  lanzador), sin animaciones de ventana, y es el compositor por defecto de Raspberry Pi OS en el Pi 5.
  Decisión del usuario frente a un tiling compositor y a un escritorio tipo GNOME/XFCE. El usuario
  no quiere nada de Hyprland en el repo salvo hyprlock/hypridle (le gustan).
- **Archivos**: `os/dotfiles/labwc/` (`rc.xml` atajos/reglas, `menu.xml` menús en castellano,
  `autostart`, `environment`), tema de ventanas `os/branding/labwc/Command/labwc/` (`themerc` +
  botones SVG de `build/make-labwc-buttons.py`) instalado en `/usr/share/themes/Command`. Portales en
  `os/dotfiles/xdg-desktop-portal/labwc-portals.conf` (gtk + wlr). Ayuda de atajos
  `os/bin/command-os-keys` (Super+F1): si se cambia un atajo en `rc.xml`, cambiarlo también ahí.
  `os/bin/command-os-about` (Super+F2, o «acerca de cmd-os» en el menú): mismo panel de wofi; lee el
  paquete de `/usr/share/command-os/version`, la fecha de Arch de `pacman/snapshot-date` y la GPU de
  `fastfetch -s gpu --format json` (fastfetch ya no admite opciones de módulo por línea de comandos).
  Las etiquetas son ASCII: `printf '%-9s'` cuenta bytes y desalinea las acentuadas.
- **Escritorios** (petición del usuario: que no se vean si no se crea uno extra): labwc no crea
  escritorios en caliente, así que `os/bin/command-os-desktops nuevo|quitar` reescribe `<names>` en
  `~/.config/labwc/rc.xml`, recarga con SIGHUP y, al crear, salta al nuevo pulsando Super+N con
  `wtype` (labwc no tiene IPC). Quitar solo quita el último; labwc pasa sus ventanas al primero.
  Waybar los enseña a la derecha y `style.css` oculta el botón cuando es `:only-child`. Re-ejecutar
  `install.sh` vuelve a dejar uno solo.
- **fastfetch**: logo de la C generado por `build/make-fastfetch-logo.py` (medios bloques, colores
  `$1`/`$2`) y configuración en `os/branding/fastfetch/`, instalados en `/usr/share/command-os/` y
  `/etc/xdg/fastfetch/`. El logo también va como icono del sistema (`/usr/share/pixmaps/command-os.png`,
  `LOGO=` de `os-release`).
- **Piezas**: swaybg (fondo), Waybar con `ext/workspaces` (labwc implementa ext-workspace) y
  `wlr/taskbar`, hyprlock/hypridle (bloqueo e inactividad por protocolos estándar; pantalla con
  `wlopm`), polkit-gnome, nm-applet en la bandeja, wdisplays, xorg-xwayland (arranca bajo demanda).
- **Ajustes por máquina** (los genera `install.sh`, no van en los dotfiles): `environment.d/local.env`
  (teclado de `/etc/command-os/kb_layout`) y `themerc-override` (sin sombras en VM). En VirtualBox,
  `video=1280x720` en la línea del kernel: todo el arranque y el escritorio a esa resolución.
- **GTK**: las apps con cabecera propia (GTK 4, Firefox) no reciben marco de labwc; `gtk-3.0/gtk.css`
  y `gtk-4.0/gtk.css` les dibujan el mismo filo rojo y halo.
- **Verificado en VM VirtualBox** (capturas): escritorio, barra con tareas, ventanas activa/inactiva
  (borde `#D13449` medido), botones, menú de ventana, Alt+Tab, lanzador con Super, ayuda de atajos,
  mezclador desplegable, bloqueo y desbloqueo, bloqueo automático a los 5 min, notificaciones, crear,
  usar y quitar escritorios, fastfetch, re-ejecución de `install.sh` con la sesión abierta y
  reinicio completo (splash → escritorio). Uso de memoria del sistema: ~616 MB. **No verificado**:
  clic derecho en el escritorio (sin ratón virtual), apagado de pantalla a los 10 min, teclas
  multimedia, Pi 5 y bare metal.
- **VirtualBox y el reposo del PC**: si Windows suspende con la VM encendida, al volver la VM se
  congela (log: dos SUSPENDING/RESUMING seguidos; el disco tardó 5 s en suspender) y no responde ni
  a SSH ni al botón ACPI. Solo queda `controlvm poweroff`; ext4 recupera el diario solo y la ESP
  (FAT) queda marcada sucia: `umount /boot && fsck.fat -a /dev/sda1 && mount /boot`. Apagar la VM
  antes de dejar el PC en reposo.
- Cómo probar sin ratón (wtype, SIGHUP, bloqueo de la sesión de tty1, capturas): `docs/testing.md`,
  sección "labwc en la VM".


## Rediseño "ordenador real de Cyberpunk" (2026-10-05, rama `rediseno`)

Criterio del usuario: se queda lo que **sirve** y lo que **crea ambiente y queda bien**; fuera lo que
ni sirve ni aporta ambiente. Detalle visual en `docs/DISENO.md`. El usuario pidió que se le pregunte
antes de cada cambio y que se le notifique (PushNotification) cuando haga falta su decisión.
- **Fondos** (`build/make-wallpaper.py`, numpy): gráfica de producto, **no paisajes** (el usuario
  rechazó skyline y mapa). `interfaz` (de serie), `nucleo`, `placa` en JPEG q93 y `void` en PNG sin
  grano para bloqueo y GRUB. Microtexto con JetBrains Mono de `build/fonts/` (OFL, solo para
  generar). Selector `os/bin/command-os-wallpaper` (elección en `~/.config/command-os/wallpaper`),
  lo llama `autostart` y el menú ajustes → fondo de pantalla. `.gitattributes`: `*.jpg binary`
  en `os/branding/` (si no, la regla de texto los corrompería).
- **Barra**: reloj con fecha (Waybar pasa **un** argumento de fecha: con dos `{:...}` el módulo no
  arranca; usar `{0:%d.%m}  {0:%H:%M}`), temperatura (en la VM no hay `thermal_zone0` y el módulo
  se desactiva solo, es normal), batería con tiempo restante, señal wifi, umbrales ámbar/rojo.
- **Ventanas**: barra de título plana, títulos y Alt+Tab en JetBrains Mono, halo de 12 px.
- **Bloqueo**: `immediate_render` (sin él, hyprlock espera hasta 2 s a sus recursos antes de
  bloquear) y el sonido de bloqueo en segundo plano en `hypridle.conf` (antes bloqueaba al terminar
  el sonido). Medido: Super+L → sesión bloqueada en ~350 ms. Línea de estado real
  (`os/bin/command-os-status`), intentos fallidos y aviso de mayúsculas en ámbar.
- **Sonidos** (`build/make-sounds.py`, numpy): de aparato real (clics, pitidos, barridos, golpe de
  encendido), sala seca. `login.wav` eliminado (no se usaba). **No se han escuchado**: verificado
  solo que no saturan; que el usuario los oiga.
- **Paquetes**: fuera las herramientas personales de desarrollo (alacritty, vim, tmux, htop, ripgrep,
  fd, fzf, bat, eza, zoxide, jq, tree, rsync, wget, nodejs, npm…) y sus alias del `bashrc`. python
  ya no está en la lista pero sigue instalado porque kitty depende de él. Se quedan base-devel + git
  (AUR). En máquinas ya instaladas `install.sh` no desinstala nada: en la VM se quitó a mano.
- **SSH**: apagado en el producto; `install.sh` lo enciende solo con la variante `vbox` o
  `COMMAND_OS_SSH=1` (lo pasan `build-image.sh` si hay `DEV_SSH_PUBKEY` y el script de Packer).
- Al probar: reiniciar hypridle por SSH lo deja escuchando la sesión SSH, no la de tty1 (Super+L deja
  de bloquear). Para aplicar cambios de la sesión, `sudo systemctl restart greetd` (tty1 es de greetd desde el 2026-10-07) y comprobar
  que no queden dos hypridle.


## Menú de energía y mezclador (2026-10-04)

- `os/bin/command-os-power`: Super+Escape o botón 󰐥 de la barra → bloquear / reiniciar / apagar (con
  confirmación), por logind sin contraseña. Verificado en VM: apagado limpio en ~6 s.
- `os/bin/command-os-volume`: clic en `vol` → pavucontrol 460×340 sin barra de título bajo la barra
  (regla en `labwc/rc.xml`); otro clic lo cierra.
- VirtualBox: la X de la ventana pregunta; "Enviar la señal de apagado" es limpio, "Apagar la
  máquina" es desenchufar.


## Consola de desarrollo, animaciones y sonido (2026-10-01)

- **Paquetes de desarrollo** en `os/packages.txt` (nano, base-devel, man, ripgrep, fd, fzf, bat, eza,
  zoxide, tmux, jq, python, nodejs/npm…) y pila de audio PipeWire completa. `install.sh` instala
  `~/.config/command-os/bashrc` (alias, prompt de marca, `EDITOR=nano`) enganchado desde `~/.bashrc`
  con marcadores, y `~/.config/nano/nanorc`.
- **Animaciones**: con labwc no hay animaciones de ventana; el movimiento está en los paneles
  (entrada de Wofi con `@keyframes`) y en las transiciones CSS de Waybar (ver `docs/DISENO.md`).
- **Sonidos**: `build/make-sounds.py` los genera en `os/branding/sounds/`; `os/bin/command-os-sound`
  los reproduce (arranque, notificación, urgente, bloqueo, desbloqueo, tecla de volumen).
- **VirtualBox**: 4 vCPU solo con CPU hotplug (sin hotplug, 2 vCPU = cuelgue en `DXE_AP`), 6 GB de
  RAM, paravirt KVM, y **audio AC97** (con HDA `pw-play` se cuelga). El escritorio renderiza por software
  en la VM, así que la fluidez real de las animaciones solo se juzga en bare metal / Pi. Detalle en
  `docs/testing.md`.
- Al iterar con labwc, re-ejecutar `install.sh` con la sesión abierta funciona; para ver los cambios,
  `kill -HUP $(pidof labwc)` (o `sudo systemctl restart greetd` para una sesión nueva).
- Pendiente: oír los sonidos en la VM (solo se verificó que `pw-play` termina a tiempo, no el
  resultado acústico), validar los paquetes en aarch64 y probar el audio en el Pi.
