#!/usr/bin/env bash
# Command OS — prueba del escritorio sin pantalla. Arranca una sesión real (labwc sin pantalla, con
# render por software) con el paquete command-os instalado y comprueba que todo arranca bien: es lo
# que detecta que una actualización de Arch (labwc, Waybar, mako, hyprlock…) ha roto algo.
#
# Se ejecuta como root en un Arch con el paquete instalado (GitHub Actions, ver
# .github/workflows/pruebas.yml). Deja en $SALIDA (por defecto ./resultados) los registros y una
# captura de pantalla. Sale con 1 si algo falla.
set -uo pipefail

SALIDA=${SALIDA:-$PWD/resultados}
USUARIO=prueba
mkdir -p "${SALIDA}"
fallos=0
ok() { echo "  ok   $*"; }
mal() { echo "  MAL  $*"; fallos=$((fallos + 1)); }

echo "==> Preparación"
id "${USUARIO}" >/dev/null 2>&1 || useradd -m -s /bin/bash "${USUARIO}"
uid=$(id -u "${USUARIO}")
run="/tmp/prueba-runtime"
rm -rf "${run}"; install -d -m 700 -o "${USUARIO}" "${run}"
como() { runuser -u "${USUARIO}" -- env HOME="/home/${USUARIO}" XDG_RUNTIME_DIR="${run}" "$@"; }

echo "==> Configuración de serie"
# Configuraciones de hyprlock: hyprlock las lee antes de conectarse a una pantalla.
for cfg in /etc/xdg/hypr/hyprlock.conf /usr/share/command-os/config/hypr/hyprlock-emergencia.conf; do
  if (ulimit -c 0; exec 2>&1; WAYLAND_DISPLAY=sin-pantalla exec hyprlock --config "${cfg}") | grep 'Config error' \
      > "${SALIDA}/hyprlock-$(basename "${cfg}").txt"; then
    mal "hyprlock: errores en ${cfg} (ver resultados)"
  else
    ok "hyprlock: ${cfg}"
  fi
done
# Arranque (lib/apply-boot, al instalarse el paquete): menú oculto y sin las entradas «EFI BootNext».
if [[ -f /etc/default/grub ]]; then
  for k in GRUB_DISABLE_BOOTNEXT=true GRUB_TIMEOUT_STYLE=hidden 'GRUB_DISTRIBUTOR="Command OS"'; do
    if grep -qxF "${k}" /etc/default/grub; then ok "GRUB: ${k}"; else mal "GRUB: falta ${k}"; fi
  done
  # Tema de GRUB a la medida de la pantalla (sin pantalla en el contenedor: medidas de 1080 px).
  tema=/boot/grub/themes/command
  if [[ -s "${tema}/theme.txt" && -s "${tema}/cmd-menu.pf2" && -s "${tema}/logo.png" ]] \
      && grep -qxF "GRUB_THEME=\"${tema}/theme.txt\"" /etc/default/grub; then
    ok "GRUB: tema de Command OS"
  else
    mal "GRUB: falta el tema (${tema})"
  fi
  if COMMAND_OS_PANTALLA=2560x1600 /usr/lib/command-os/apply-boot \
      && grep -q 'pantallas de 1600 px' "${tema}/theme.txt" && grep -qxF 'GRUB_GFXMODE=2560x1600,auto' /etc/default/grub; then
    ok "GRUB: tema y modo para 2560x1600"
  else
    mal "GRUB: tema o modo para 2560x1600"
  fi
  if COMMAND_OS_PANTALLA=generica /usr/lib/command-os/apply-boot \
      && grep -q 'pantallas de 1080 px' "${tema}/theme.txt" && grep -qxF 'GRUB_GFXMODE=auto' /etc/default/grub; then
    ok "GRUB: imagen genérica (auto y medidas de 1080)"
  else
    mal "GRUB: imagen genérica"
  fi
  /usr/lib/command-os/apply-boot
else
  mal "no hay /etc/default/grub (falta grub en el contenedor)"
fi
for f in /etc/xdg/labwc/rc.xml /usr/share/command-os/config/labwc/menu.xml; do
  if xmllint --noout "${f}" 2>"${SALIDA}/xmllint-$(basename "${f}").txt"; then ok "XML: ${f}"; else mal "XML: ${f}"; fi
done

echo "==> Instalar aplicaciones (tienda, comprimidos, tipos de archivo)"
# Lo que se descarga se abre con su aplicación de serie, sin preguntar: GIO (Thunar, Firefox) la da como
# la de cada tipo de /usr/share/applications/mimeapps.list. Si Arch cambia el nombre de un .desktop
# (Bazaar, xarchiver), esto falla antes de que llegue a los equipos.
antes=${fallos}
while IFS='=' read -r tipo app; do
  if [[ ! -f "/usr/share/applications/${app}" ]]; then
    mal "tipos: no existe ${app} (${tipo})"
  elif [[ "$(como gio mime "${tipo}" 2>/dev/null | head -1)" != *"${app}"* ]]; then
    mal "tipos: ${tipo} no se abre con ${app} ($(como gio mime "${tipo}" 2>&1 | head -1))"
  fi
done < <(sed -n 's/^\([a-z-]*\/[^=]*\)=\(.*\)$/\1=\2/p' /usr/share/applications/mimeapps.list)
(( fallos == antes )) && ok "tipos: cada uno se abre con su aplicación de serie"
# La tienda y el gestor de comprimidos arrancan con las bibliotecas de esta fecha de Arch (LD_BIND_NOW
# resuelve todos los símbolos al empezar). En la foto del 2026/10/05, Bazaar venía compilado contra un
# libdex más nuevo y no abría (docs/decisiones.md): una fecha así no se valida.
for p in bazaar xarchiver; do
  if (LD_BIND_NOW=1 timeout 10 "${p}" --help 2>&1 || true) | grep -qE 'symbol lookup error|error while loading shared libraries'; then
    mal "${p}: no arranca con las bibliotecas de esta fecha"
  else
    ok "${p}: enlaza con las bibliotecas de esta fecha"
  fi
done
if flatpak remotes --system --columns=name 2>/dev/null | grep -qx flathub; then ok "flatpak: Flathub de serie"; else mal "flatpak: sin Flathub"; fi
if grep -qs 'xdg-config/gtk-3.0:ro' /var/lib/flatpak/overrides/global; then
  ok "flatpak: las apps leen el tema GTK del usuario"
else
  mal "flatpak: sin el permiso global del tema (lib/apply-system)"
fi
# La sesión ve las aplicaciones de la tienda: command-os-session con un labwc de mentira que apunta su
# XDG_DATA_DIRS (de ahí leen el lanzador y las fijadas).
install -d -o "${USUARIO}" "${run}/bin"
printf '#!/bin/sh\necho "$XDG_DATA_DIRS" > "%s/datos"\n' "${run}" > "${run}/bin/labwc"
chmod 755 "${run}/bin/labwc"
como env PATH="${run}/bin:${PATH}" command-os-session
if [[ ":$(cat "${run}/datos" 2>/dev/null):" == *":/var/lib/flatpak/exports/share:"*":/usr/share:"* ]]; then
  ok "sesión: el lanzador ve las aplicaciones Flatpak"
else
  mal "sesión: XDG_DATA_DIRS sin Flatpak ($(cat "${run}/datos" 2>/dev/null))"
fi
rm -rf "${run}/bin" "${run}/datos"

echo "==> Sesión de labwc sin pantalla"
como command-os-user-setup || mal "command-os-user-setup"
# Sesión de prueba: render por software, sin dispositivos de entrada.
como dbus-run-session -- env WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 \
  WLR_HEADLESS_OUTPUTS=1 labwc --merge-config > "${SALIDA}/labwc.log" 2>&1 &
sleep 12

for p in labwc waybar mako hypridle swaybg; do
  if pgrep -u "${uid}" -x "${p}" >/dev/null; then ok "en marcha: ${p}"; else mal "no arrancó: ${p}"; fi
done
# Aplicaciones fijadas (command-os-fijadas): la barra arranca con su hoja de estilo y su configuración.
if [[ -s "${run}/command-os/barra/fijadas.jsonc" ]] && ! grep -aq 'Unable to find resource file' "${SALIDA}/labwc.log" \
    && pgrep -u "${uid}" -a waybar | grep -qF -- "--style ${run}/command-os/barra/estilo.css"; then
  ok "barra: aplicaciones fijadas"
else
  mal "barra: sin las aplicaciones fijadas (ver labwc.log)"
fi
if grep -aqiE 'error parsing config|parser error|no menu with id|already exists' "${SALIDA}/labwc.log"; then
  mal "labwc: errores en su configuración (ver labwc.log)"
else
  ok "labwc: configuración sin errores"
fi
if grep -aqiE '\[error\]|critical' "${SALIDA}/labwc.log"; then
  # nm-applet suelta avisos internos de GTK sin consecuencias (y, al arrancar, la bandeja de Waybar
  # avisa de su icono aún vacío: «No icon name or pixmap»); la temperatura y la batería no
  # existen en una máquina sin hardware; tampoco rfkill ni el bus del sistema (hypridle lo busca
  # para logind y en el contenedor de CI no hay systemd).
  grep -aiE '\[error\]|critical' "${SALIDA}/labwc.log" \
    | grep -viE 'thermal|temperature|batter|tray|StatusNotifier|nm-applet|No icon name or pixmap|RFKILL|Couldn.t create the dbus connection' \
    | head -5 > "${SALIDA}/errores-programas.txt"
  if [[ -s "${SALIDA}/errores-programas.txt" ]]; then mal "errores de programas (ver errores-programas.txt)"; fi
fi

display=$(basename "$(ls "${run}"/wayland-* 2>/dev/null | grep -v '\.lock$' | head -1)")

# Escala de las pantallas (command-os-pantallas): la ve, y la configuración de hyprlock escalada a 2
# es válida para hyprlock (si no, el bloqueo pasaría a la de emergencia).
if [[ -n "${display}" ]]; then
  pantalla=$(como env WAYLAND_DISPLAY="${display}" command-os-pantallas lista 2>&1 | head -1)
  if [[ "${pantalla}" =~ ^[A-Za-z0-9-]+\ [0-9]+\ [0-9]+\ 1$ ]]; then ok "pantallas: ${pantalla}"; else mal "pantallas: ${pantalla}"; fi
  como env WAYLAND_DISPLAY="${display}" wlr-randr --output "${pantalla%% *}" --scale 2 >/dev/null 2>&1
  como env WAYLAND_DISPLAY="${display}" command-os-pantallas hyprlock /etc/xdg/hypr/hyprlock.conf \
    > "${run}/hyprlock-escalado.conf" 2>"${SALIDA}/hyprlock-escalado.txt"
  if grep -q 'font_size = 128' "${run}/hyprlock-escalado.conf" \
      && ! (ulimit -c 0; exec 2>&1; WAYLAND_DISPLAY=sin-pantalla exec hyprlock --config "${run}/hyprlock-escalado.conf") \
        | grep 'Config error' >> "${SALIDA}/hyprlock-escalado.txt"; then
    ok "hyprlock: configuración escalada a 2"
  else
    mal "hyprlock: configuración escalada (ver hyprlock-escalado.txt)"
  fi
  como env WAYLAND_DISPLAY="${display}" wlr-randr --output "${pantalla%% *}" --scale 1 >/dev/null 2>&1
fi

# Captura de la sesión para revisarla a ojo en los artefactos de GitHub Actions.
if [[ -n "${display}" ]] && como env WAYLAND_DISPLAY="${display}" grim "${run}/escritorio.png" \
    && cp "${run}/escritorio.png" "${SALIDA}/"; then
  ok "captura: escritorio.png"
else
  mal "no se pudo hacer la captura"
fi

pkill -u "${uid}" -x labwc
sleep 1
echo
if (( fallos )); then echo "==> ${fallos} fallo(s)"; exit 1; fi
echo "==> Todo correcto"
