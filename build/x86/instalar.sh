#!/usr/bin/env bash
# Asistente de instalación de Command OS en un PC x86_64. Se ejecuta como root desde el USB en vivo
# de Arch Linux (pasos en docs/instalacion.md):
#   bash command-os/build/x86/instalar.sh
# Pregunta cómo instalar y en qué disco, y llama al instalador que toca:
#   1. junto a Windows (dual boot): build/x86/install-dualboot.sh, no borra nada
#   2. como sistema principal:     build/x86/install-disco.sh, borra el disco entero
# Cada instalador vuelve a comprobar el disco y pide su propia confirmación antes de tocarlo.
# Acepta las mismas variables que ellos (KB_LAYOUT, TIMEZONE, HOSTNAME_NEW, VARIANT…).
set -euo pipefail

REPO=$(cd "$(dirname "$0")/../.." && pwd)
source "${REPO}/build/x86/lib.sh"
die() { echo "error: $*" >&2; exit 1; }

[[ $(id -u) -eq 0 ]] || die "ejecutar como root"
require_live_usb
[[ -d /sys/firmware/efi ]] || die "el USB no arrancó en modo UEFI (desactiva CSM/Legacy en la BIOS)"
# ping, y si la red bloquea ICMP, una petición HTTPS (lo que de verdad usa la instalación).
ping -c 1 -W 5 archlinux.org >/dev/null 2>&1 || curl -fsI --max-time 15 https://archlinux.org >/dev/null 2>&1 \
  || die "sin internet: conecta el cable o el wifi (iwctl) y vuelve a empezar"

cat <<'EOF'

  Command OS: instalación en este equipo

  1) Junto a Windows (dual boot)
     Windows se queda; al encender eliges cuál arrancar. Necesita espacio libre sin particionar
     (≥ 30 GB, se libera desde Windows: docs/dualboot.md).
  2) Como sistema principal
     Command OS ocupa el disco entero. BORRA TODO LO QUE TENGA (Windows y archivos incluidos).

EOF
read -rp "Elige 1 o 2 (otra cosa cancela): " modo
case "${modo}" in
  1) script=install-dualboot.sh ;;
  2) script=install-disco.sh ;;
  *) echo "cancelado"; exit 1 ;;
esac

# Discos del equipo sin el USB en vivo. Para el disco entero, los que no se pueden borrar salen sin
# número y con el motivo (lib.sh: disk_problems); en el dual boot lo que cuenta es el hueco libre,
# y eso lo mira install-dualboot.sh.
mapfile -t discos < <(lsblk -dpno NAME,TYPE | awk '$2 == "disk" { print $1 }')
opciones=()
echo
for d in "${discos[@]}"; do
  problemas=$(disk_problems "${d}")
  grep -qE 'USB de instalación|sistema que está en marcha' <<< "${problemas}" && continue
  datos="$(printf '%-14s %8s  %s' "${d}" "$(lsblk -dno SIZE "${d}" | tr -d ' ')" "$(lsblk -dno MODEL,TRAN "${d}" | xargs)")"
  if [[ "${modo}" == 2 && -n "${problemas}" ]]; then
    printf '     %s  (no: %s)\n' "${datos}" "$(head -n 1 <<< "${problemas}" | sed "s|^${d} ||")"
    continue
  fi
  opciones+=("${d}")
  printf '  %d) %s\n' "${#opciones[@]}" "${datos}"
done
(( ${#opciones[@]} )) || die "no hay ningún disco donde instalar"
echo
read -rp "¿En qué disco? (número; otra cosa cancela): " n
[[ "${n}" =~ ^[0-9]+$ ]] && (( n >= 1 && n <= ${#opciones[@]} )) || { echo "cancelado"; exit 1; }

exec bash "${REPO}/build/x86/${script}" "${opciones[n - 1]}"
