#!/usr/bin/env bash
# Command OS — medida de ligereza en la VM de VirtualBox, siempre igual: reinicia command-os-x86, mide con
# os/bin/command-os-medir (el de este árbol, aunque el paquete de la VM sea otro) y repite N arranques. Apunta
# la mediana en docs/medidas/registro.tsv y el detalle por programa del arranque mediano en
# docs/medidas/procesos.tsv, con la fecha, el commit y la versión del paquete (docs/testing.md § «Medir la
# ligereza»). Corre en el anfitrión (Git Bash en Windows o Linux con VBoxManage).
#
#   bash build/x86/medir-vm.sh [-n ARRANQUES] [--instalar] [--nota TEXTO] [--sin-registro]
#
#   -n           arranques que se miden (3 de serie; se apunta la mediana de cada cifra)
#   --instalar   antes de medir, instala en la VM el paquete de este árbol (os/install.sh)
#   --nota       texto libre para la columna «nota» del registro (qué se cambió)
#   --sin-registro  solo enseña las cifras
set -uo pipefail

RAIZ=$(cd "$(dirname "$0")/../.." && pwd)
VM=${COMMAND_OS_VM:-command-os-x86}
PUERTO=${COMMAND_OS_VM_SSH:-2902}
VB=${VBOXMANAGE:-$(command -v VBoxManage || echo "/c/Program Files/Oracle/VirtualBox/VBoxManage.exe")}
REGISTRO="${RAIZ}/docs/medidas/registro.tsv"
PROCESOS="${RAIZ}/docs/medidas/procesos.tsv"
N=3
INSTALAR=0
NOTA=""
APUNTAR=1

while [ $# -gt 0 ]; do
  case "$1" in
    -n) N=$2; shift ;;
    --instalar) INSTALAR=1 ;;
    --nota) NOTA=$2; shift ;;
    --sin-registro) APUNTAR=0 ;;
    *) sed -n '9,13p' "$0" >&2; exit 2 ;;
  esac
  shift
done

S=(ssh -o BatchMode=yes -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=ERROR
   -o ConnectTimeout=5 -i "${RAIZ}/build/packer/keys/packer_build_key" -p "${PUERTO}" deck@127.0.0.1)
# sudo por SSH con la entrada estándar libre: si va ocupada, cuenta como contraseña mal puesta (faillock)
como_root() { "${S[@]}" "echo deck | sudo -S -p '' $*"; }

estado() { "${VB}" showvminfo "${VM}" --machinereadable | sed -n 's/^VMState="\(.*\)"/\1/p'; }
boot_id() { "${S[@]}" 'cat /proc/sys/kernel/random/boot_id' 2>/dev/null; }

# Arranca la VM (o la reinicia si ya está encendida) y espera a que responda por SSH con otro arranque
arrancar() {
  local antes="" i nuevo
  if [ "$(estado)" = running ]; then
    antes=$(boot_id)
    como_root systemctl reboot >/dev/null 2>&1
  else
    "${VB}" startvm "${VM}" --type headless >/dev/null || return 1
  fi
  for i in $(seq 1 60); do
    sleep 5
    nuevo=$(boot_id)
    [ -n "${nuevo}" ] && [ "${nuevo}" != "${antes}" ] && return 0
  done
  echo "medir-vm: la VM no responde por SSH tras 5 min" >&2
  return 1
}

T=$(mktemp -d)
trap 'rm -rf "${T}"' EXIT

if [ "${INSTALAR}" = 1 ]; then
  [ "$(estado)" = running ] || arrancar || exit 1
  echo "Instalando el paquete de este árbol en la VM…"
  (cd "${RAIZ}" && git ls-files -co --exclude-standard os | tar -czf - -T -) |
    "${S[@]}" 'rm -rf /tmp/command-os && mkdir -p /tmp/command-os && tar -xzf - -C /tmp/command-os' || exit 1
  como_root env COMMAND_OS_VARIANT=vbox bash /tmp/command-os/os/install.sh > "${T}/instalar.log" 2>&1 ||
    { tail -n 20 "${T}/instalar.log" >&2; echo "medir-vm: falló install.sh" >&2; exit 1; }
fi

for i in $(seq 1 "${N}"); do
  echo "Arranque ${i} de ${N}…"
  arrancar || exit 1
  "${S[@]}" 'cat > /tmp/command-os-medir' < "${RAIZ}/os/bin/command-os-medir" || exit 1
  como_root bash /tmp/command-os-medir --tsv > "${T}/medida.${i}" || { echo "medir-vm: falló la medida" >&2; exit 1; }
  awk -F'\t' '$1 == "R" && ($2 == "escritorio_s" || $2 == "mem_usada_mb" || $2 == "pss_total_mb" ||
    $2 == "procesos_tics_min") { printf "  %s %s", $2, $3 } END { print "" }' "${T}/medida.${i}"
done
version=$("${S[@]}" 'pacman -Q command-os' 2>/dev/null | awk '{ print $2 }')

# Mediana de cada cifra del resumen; el detalle por programa, del arranque con la memoria usada mediana
mediana() {
  awk -F'\t' -v c="$1" '$1 == "R" && $2 == c { print $3 }' "${T}"/medida.* | sort -n |
    awk '{ v[NR] = $1 } END { if (NR == 0 || v[1] == "") print ""; else if (NR % 2) print v[(NR + 1) / 2];
      else print v[NR / 2] + (v[NR / 2 + 1] - v[NR / 2]) / 2 }'
}
dato() { awk -F'\t' -v c="$1" '$1 == "R" && $2 == c { print $3; exit }' "${T}/medida.1"; }
m_mem=$(mediana mem_usada_mb)
elegido=$(for f in "${T}"/medida.*; do
  printf '%s\t%s\n' "$(awk -F'\t' '$2 == "mem_usada_mb" { print $3 }' "${f}")" "${f}"
done | sort -n | awk -F'\t' -v n="${N}" 'NR == int((n + 1) / 2) { print $2 }')

fecha=$(date '+%Y-%m-%d %H:%M')
commit=$(git -C "${RAIZ}" rev-parse --short HEAD)
[ -n "$(git -C "${RAIZ}" status --porcelain -- os)" ] && commit="${commit}+cambios"
rama=$(git -C "${RAIZ}" rev-parse --abbrev-ref HEAD)

fila=$(printf '%s\t' "${fecha}" "${commit}" "${rama}" vbox "${version}" "$(dato sesion)" "${N}" \
  "$(mediana escritorio_s)" "$(mediana kernel_s)" "$(mediana initrd_s)" "$(mediana userspace_s)" "${m_mem}" \
  "$(mediana pss_total_mb)" "$(mediana procesos_tics_min)" "$(mediana cpu_tics_min)" "$(dato espera_s)" \
  "$(dato ventana_s)")
fila="${fila}${NOTA}"

echo
echo "Mediana de ${N} arranques (${commit}, command-os ${version}):"
paste <(sed -n 1p "${REGISTRO}" 2>/dev/null | tr '\t' '\n') <(printf '%s\n' "${fila}" | tr '\t' '\n') | sed 's/^/  /'
echo
echo "Por programa (arranque mediano, PSS y RSS en MB, tics por minuto):"
awk -F'\t' '$1 == "P"' "${elegido}" | head -n 12 | awk -F'\t' -v v="$(dato ventana_s)" \
  '{ printf "  %-22s %3d %8.1f %8.1f %6.0f\n", $2, $3, $4 / 1024, $5 / 1024, $6 * 60 / v }'

if [ "${APUNTAR}" = 1 ]; then
  printf '%s\n' "${fila}" >> "${REGISTRO}"
  awk -F'\t' -v OFS='\t' -v f="${fecha}" -v c="${commit}" -v v="$(dato ventana_s)" \
    '$1 == "P" { n++; if (n <= 12) print f, c, $2, $3, $4, $5, sprintf("%.0f", $6 * 60 / v) }' \
    "${elegido}" >> "${PROCESOS}"
  echo
  echo "Apuntado en docs/medidas/registro.tsv y docs/medidas/procesos.tsv."
fi
