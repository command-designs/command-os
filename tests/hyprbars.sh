#!/usr/bin/env bash
# Command OS — las barras de título de la sesión Hyprland (os/hyprbars: hyprbars con el parche de Command OS)
# frente al Hyprland instalado. Un plugin compilado para otro Hyprland no carga y la sesión se queda sin
# barras: esta prueba es la que impide validar una fecha de Arch con otro Hyprland sin poner antes el
# plugin al día (docs/actualizaciones.md § 4).
#
# Se ejecuta como root en un Arch con Hyprland y el plugin compilado (GitHub Actions, escritorio.yml):
#   bash tests/hyprbars.sh [hyprbars.so]      (por defecto, el instalado: /usr/lib/command-os/hyprbars.so)
# Sale con 1 si algo falla.
set -uo pipefail
cd "$(dirname "$0")/.." || exit 1

SO=${1:-/usr/lib/command-os/hyprbars.so}
USUARIO=${USUARIO:-prueba}
fallos=0
ok() { echo "  ok   $*"; }
mal() { echo "  MAL  $*"; fallos=$((fallos + 1)); }

echo "==> hyprbars"
[[ -f "${SO}" ]] || { mal "no está el plugin: ${SO}"; exit 1; }

# 1. La versión de Hyprland para la que está hecho el paquete es la instalada.
quiere=$(sed -n 's/^_hyprland=//p' os/hyprbars/PKGBUILD)
hay=$(pacman -Q hyprland 2>/dev/null | awk '{print $2}' | sed 's/-[0-9.]*$//')
if [[ -n "${quiere}" && "${hay}" == "${quiere}" ]]; then
  ok "hyprland ${hay}, el de os/hyprbars/PKGBUILD"
else
  mal "hyprland ${hay:-no instalado} y os/hyprbars/PKGBUILD es para ${quiere}: poner su versión, el commit de hyprland-plugins (hyprpm.toml) y el parche al día"
fi

# 2. Compilado con las cabeceras de este Hyprland (el commit va en la comprobación de versión del plugin).
# El commit, de version.h (del mismo paquete que el binario): `Hyprland --version` no lo da en el
# contenedor de la CI.
commit=$(grep -oE 'GIT_COMMIT_HASH +"[0-9a-f]{40}"' /usr/include/hyprland/src/version.h 2>/dev/null | grep -oE '[0-9a-f]{40}')
if [[ -n "${commit}" ]] && grep -aqF "${commit}" "${SO}"; then
  ok "compilado para el commit ${commit:0:8} de Hyprland"
else
  mal "el plugin no es para este Hyprland (commit ${commit:-desconocido})"
fi

# 3. Todo lo que el plugin usa de Hyprland y de sus bibliotecas existe en las instaladas.
definidos=$(mktemp)
{
  nm -D --defined-only /usr/bin/Hyprland
  ldd /usr/bin/Hyprland | awk '/=>/ {print $3}' | while read -r lib; do nm -D --defined-only "${lib}" 2>/dev/null; done
} | awk '{print $3}' | sed 's/@.*//' | sort -u > "${definidos}"
faltan=$(nm -D --undefined-only "${SO}" | awk '$1 == "U" {print $2}' | sed 's/@.*//' | sort -u | comm -23 - "${definidos}")
rm -f "${definidos}"
if [[ -z "${faltan}" ]]; then
  ok "todos sus símbolos están en Hyprland y sus bibliotecas"
else
  mal "símbolos que no existen en este Hyprland: $(echo "${faltan}" | head -5 | c++filt | tr '\n' ' ')"
fi

# 4. La configuración de hyprbars de hyprland.lua usa opciones, efectos y botones que existen.
# Los efectos de regla (hyprbars:bar_color) pueden ir fundidos con la opción que acaba igual
# (plugin:hyprbars:bar_color): se buscan también al final de otra cadena.
cadenas=$(strings -a "${SO}")
mapfile -t claves < <({ grep -oE '^plugin:hyprbars:[a-z_.]+$' <<< "${cadenas}"; grep -oE 'hyprbars:[a-z_]+$' <<< "${cadenas}"; } | sort -u)
if lua tests/hyprbars.lua os/dotfiles/hypr/hyprland.lua os/branding/labwc/Command/labwc "${claves[@]}"; then
  :
else
  mal "configuración de hyprbars en os/dotfiles/hypr/hyprland.lua"
fi

# 5. Los despachadores de command_os.boton (dentro de una función, --verify-config no los mira).
if command -v Hyprland >/dev/null; then
  id "${USUARIO}" >/dev/null 2>&1 || useradd -m -s /bin/bash "${USUARIO}"
  dir=$(mktemp -d)
  cat > "${dir}/botones.lua" <<'EOF'
hl.bind("SUPER + F10", hl.dsp.window.close())
hl.bind("SUPER + F11", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }))
hl.bind("SUPER + F12", hl.dsp.window.move({ workspace = "special:minimizadas", follow = false }))
EOF
  chmod 755 "${dir}"; chmod 644 "${dir}/botones.lua"
  install -d -m 700 -o "${USUARIO}" "/tmp/hyprbars-runtime"
  if runuser -u "${USUARIO}" -- env HOME="$(getent passwd "${USUARIO}" | cut -d: -f6)" XDG_RUNTIME_DIR=/tmp/hyprbars-runtime \
      Hyprland --verify-config --config "${dir}/botones.lua" 2>&1 | grep -qx 'config ok'; then
    ok "despachadores de los botones"
  else
    mal "despachadores de command_os.boton (Hyprland --verify-config --config ${dir}/botones.lua)"
  fi
  rm -rf "${dir}" /tmp/hyprbars-runtime
fi

echo
if (( fallos )); then echo "==> ${fallos} fallo(s)"; exit 1; fi
echo "==> Todo correcto"
