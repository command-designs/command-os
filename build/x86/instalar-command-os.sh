#!/usr/bin/env bash
# Command OS — instalar en un PC desde el USB en vivo de Arch Linux, sin clonar nada ni tokens
# (docs/instalacion.md):
#   curl -fLO https://github.com/command-designs/command-os-versions/releases/download/instalador/instalar-command-os.sh
#   bash instalar-command-os.sh
#
# Descarga el instalador publicado (empaquetar-instalador.sh, .github/workflows/publicar.yml), la
# clave pública y la firma, y comprueba que lo firmó la clave de Command OS (la huella va escrita
# aquí; tests/instalador.sh comprueba que es la de os/pacman/command-os.fingerprint). Si la firma no
# es buena no ejecuta nada. Después abre el asistente (build/x86/instalar.sh) con las mismas
# variables (KB_LAYOUT, CIFRADO…).
set -euo pipefail

URL=${COMMAND_OS_INSTALADOR_URL:-https://github.com/command-designs/command-os-versions/releases/download/instalador}
HUELLA=B2A680DD66E42CF295DC40BA33FF77E24580D984
DESTINO=${COMMAND_OS_INSTALADOR_DIR:-/root/command-os-instalador}

die() { echo "error: $*" >&2; exit 1; }
[[ $(id -u) -eq 0 ]] || die "ejecutar como root"
[[ -d /run/archiso || -n "${COMMAND_OS_FUERA_DEL_USB:-}" ]] \
  || die "esto se ejecuta desde el USB en vivo de Arch Linux, no desde un sistema instalado"
command -v gpg >/dev/null || die "falta gpg (en el USB de Arch viene de serie)"

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
echo "==> Descargando el instalador de Command OS"
for f in command-os-instalador.tar.gz command-os-instalador.tar.gz.sig command-os.gpg; do
  curl -fsSL --retry 3 --max-time 120 -o "${tmp}/${f}" "${URL}/${f}" \
    || die "no se pudo descargar ${f}: ¿hay internet? (cable, o wifi con iwctl)"
done

# Anillo de claves propio y vacío: solo cuenta la clave descargada, y solo si su huella es la de aquí.
export GNUPGHOME="${tmp}/gnupg"
install -d -m 700 "${GNUPGHOME}"
gpg --batch --quiet --import "${tmp}/command-os.gpg" 2>/dev/null || die "la clave descargada no es válida"
# VALIDSIG da la huella de la clave que firmó y, la última, la de su clave principal.
estado=$(gpg --batch --status-fd 1 --verify "${tmp}/command-os-instalador.tar.gz.sig" \
  "${tmp}/command-os-instalador.tar.gz" 2>/dev/null) || true
if ! awk -v h="${HUELLA}" '$1 == "[GNUPG:]" && $2 == "VALIDSIG" && ($3 == h || $NF == h) { ok = 1 } END { exit !ok }' \
  <<< "${estado}"; then
  die "la firma del instalador NO es de Command OS: no se ejecuta nada (descarga dañada o manipulada)"
fi
echo "==> Firma comprobada (clave ${HUELLA})"

rm -rf "${DESTINO}"
install -d "${DESTINO}"
tar -xzf "${tmp}/command-os-instalador.tar.gz" -C "${DESTINO}"
[[ -f "${DESTINO}/command-os/build/x86/instalar.sh" ]] || die "el instalador descargado está incompleto"
echo "==> Instalador $(cat "${DESTINO}/command-os/PUBLICADO" 2>/dev/null || echo '?')"
# exec no pasa por el trap: se limpia antes (el agente de gpg y la carpeta temporal).
gpgconf --kill gpg-agent 2>/dev/null || true
rm -rf "${tmp}"
trap - EXIT
exec bash "${DESTINO}/command-os/build/x86/instalar.sh" "$@"
