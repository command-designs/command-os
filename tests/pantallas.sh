#!/usr/bin/env bash
# Command OS — prueba de la escala de las pantallas (os/lib/pantallas.py, docs/notas/pantallas.md)
# sin pantalla: la escala que se calcula para pantallas reales conocidas y la configuración de
# hyprlock escalada. Corre en cualquier Linux con python3 (GitHub Actions, ver
# .github/workflows/pruebas.yml). Sale con 1 si algo falla.
set -uo pipefail

RAIZ=$(cd "$(dirname "$0")/.." && pwd)
P="${RAIZ}/os/lib/pantallas.py"
fallos=0
ok() { echo "  ok   $*"; }
mal() { echo "  MAL  $*"; fallos=$((fallos + 1)); }

echo "==> Escala automática (ancho alto ancho_mm alto_mm salida -> escala)"
while read -r w h mw mh n esperada caso; do
  [[ -z "${w}" || "${w}" == \#* ]] && continue
  sale=$(python3 "${P}" escala "${w}" "${h}" "${mw}" "${mh}" "${n}")
  if [[ "${sale}" == "${esperada}" ]]; then ok "${caso}: ${sale}"; else mal "${caso}: ${sale} (se esperaba ${esperada})"; fi
done <<'EOF'
2560 1600 286 179 eDP-1    2    portátil 13" 2560x1600
2560 1600 302 189 eDP-1    1.75 portátil 14" 2560x1600
1920 1200 302 189 eDP-1    1.25 portátil 14" 1920x1200
1920 1080 344 194 eDP-1    1.25 portátil 15,6" 1920x1080
1920 1080 294 165 eDP-1    1.5  portátil 13,3" 1920x1080
1366 768  256 144 eDP-1    1    portátil 11,6" 1366x768 (tope de 720 px de alto)
1280 800  261 163 eDP-1    1    portátil 12" 1280x800 (tope)
2560 1440 597 336 DP-1     1    monitor 27" 2560x1440
1920 1080 527 296 HDMI-A-1 1    monitor 24" 1920x1080
3840 2160 597 336 DP-1     1.5  monitor 27" 4K
3840 2160 1210 680 HDMI-A-1 1   televisor 55" 4K
1280 800  0   0   VGA-1    1    sin tamaño (VM)
1920 1080 16  9   HDMI-A-1 1    da la proporción en vez del tamaño
1920 1080 600 600 HDMI-A-1 1    tamaño que no casa con la proporción
EOF

echo "==> Configuración de hyprlock escalada"
salida=$(python3 - "${P}" "${RAIZ}/os/dotfiles/hypr/hyprlock.conf" <<'PY'
import importlib.util, sys
spec = importlib.util.spec_from_file_location("pantallas", sys.argv[1])
p = importlib.util.module_from_spec(spec)
spec.loader.exec_module(p)
igual = p.hyprlock(sys.argv[2], {"eDP-1": 1.0})
print("igual" if igual == open(sys.argv[2], encoding="utf-8").read() else "cambia")
doble = p.hyprlock(sys.argv[2], {"eDP-1": 2.0, "HDMI-A-1": 1.0})
print(doble.count("monitor = eDP-1"), doble.count("monitor = HDMI-A-1"))
print("font_size = 128" in doble, "size = 600, 88" in doble, "position = 0, -100" in doble)
print(p.escalar_valor("50%, 10", 2), "check_color = rgb(163, 160, 154)" in doble)
print("size = 20, 2" in doble, "position = -370, 300" in doble)  # una escuadra
PY
)
mapfile -t l <<< "${salida}"
[[ "${l[0]}" == igual ]] && ok "a escala 1 no cambia nada" || mal "a escala 1 cambia la configuración"
bloques=$(grep -cE '^(background|image|label|input-field|shape) \{' "${RAIZ}/os/dotfiles/hypr/hyprlock.conf")
[[ "${l[1]}" == "${bloques} ${bloques}" ]] && ok "un bloque por pantalla (${bloques} cada una)" \
  || mal "bloques por pantalla: ${l[1]} (se esperaban ${bloques} ${bloques})"
[[ "${l[2]}" == "True True True" ]] && ok "medidas multiplicadas (letra, campo, posición)" || mal "medidas: ${l[2]}"
[[ "${l[3]}" == "50%, 20 True" ]] && ok "porcentajes y colores intactos" || mal "porcentajes o colores: ${l[3]}"
[[ "${l[4]}" == "True True" ]] && ok "escuadras escaladas (brazo y posición)" || mal "escuadras: ${l[4]}"

echo
if (( fallos )); then echo "==> ${fallos} fallo(s)"; exit 1; fi
echo "==> Todo correcto"
