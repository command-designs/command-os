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
# variables (KB_LAYOUT, CIFRADO…) y el idioma elegido aquí (COMMAND_OS_IDIOMA=es|en).
set -euo pipefail

URL=${COMMAND_OS_INSTALADOR_URL:-https://github.com/command-designs/command-os-versions/releases/download/instalador}
HUELLA=B2A680DD66E42CF295DC40BA33FF77E24580D984
DESTINO=${COMMAND_OS_INSTALADOR_DIR:-/root/command-os-instalador}

die() { echo "error: $*" >&2; exit 1; }

# Idioma de los mensajes y del sistema: se pregunta aquí, antes de descargar nada, y pasa al
# asistente. Este script aún no tiene el catálogo de traducciones (llega con el instalador): sus
# pocos mensajes van escritos en los dos idiomas (m CASTELLANO INGLÉS). La pregunta es la misma que
# la de elegir_idioma (build/x86/lib.sh).
if [[ -z "${COMMAND_OS_IDIOMA:-}" ]]; then
  printf '\n  Idioma / Language\n    1) Español\n    2) English\n\n'
  while :; do
    read -rp "Elige / Choose [1]: " r || exit 1
    case "${r}" in ""|1) COMMAND_OS_IDIOMA=es; break ;; 2) COMMAND_OS_IDIOMA=en; break ;; esac
  done
fi
case "${COMMAND_OS_IDIOMA}" in es|en) export COMMAND_OS_IDIOMA ;; *) die "COMMAND_OS_IDIOMA: es | en" ;; esac
m() { if [[ "${COMMAND_OS_IDIOMA}" == en ]]; then printf '%s' "$2"; else printf '%s' "$1"; fi; }

[[ $(id -u) -eq 0 ]] || die "$(m 'ejecutar como root' 'run it as root')"
[[ -d /run/archiso || -n "${COMMAND_OS_FUERA_DEL_USB:-}" ]] \
  || die "$(m 'esto se ejecuta desde el USB en vivo de Arch Linux, no desde un sistema instalado' \
    'this runs from the Arch Linux live USB, not from an installed system')"
command -v gpg >/dev/null || die "$(m 'falta gpg (en el USB de Arch viene de serie)' 'gpg is missing (the Arch USB ships it)')"

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
echo "==> $(m 'Descargando el instalador de Command OS' 'Downloading the Command OS installer')"
for f in command-os-instalador.tar.gz command-os-instalador.tar.gz.sig command-os.gpg; do
  curl -fsSL --retry 3 --max-time 120 -o "${tmp}/${f}" "${URL}/${f}" \
    || die "$(m "no se pudo descargar ${f}: ¿hay internet? (cable, o wifi con iwctl)" \
      "could not download ${f}: is there internet? (cable, or wifi with iwctl)")"
done

# Anillo de claves propio y vacío: solo cuenta la clave descargada, y solo si su huella es la de aquí.
export GNUPGHOME="${tmp}/gnupg"
install -d -m 700 "${GNUPGHOME}"
gpg --batch --quiet --import "${tmp}/command-os.gpg" 2>/dev/null || die "$(m 'la clave descargada no es válida' 'the downloaded key is not valid')"
# VALIDSIG da la huella de la clave que firmó y, la última, la de su clave principal.
estado=$(gpg --batch --status-fd 1 --verify "${tmp}/command-os-instalador.tar.gz.sig" \
  "${tmp}/command-os-instalador.tar.gz" 2>/dev/null) || true
if ! awk -v h="${HUELLA}" '$1 == "[GNUPG:]" && $2 == "VALIDSIG" && ($3 == h || $NF == h) { ok = 1 } END { exit !ok }' \
  <<< "${estado}"; then
  die "$(m 'la firma del instalador NO es de Command OS: no se ejecuta nada (descarga dañada o manipulada)' \
    'the installer signature is NOT from Command OS: nothing is run (damaged or tampered download)')"
fi
echo "==> $(m 'Firma comprobada' 'Signature verified') (${HUELLA})"

rm -rf "${DESTINO}"
install -d "${DESTINO}"
tar -xzf "${tmp}/command-os-instalador.tar.gz" -C "${DESTINO}"
[[ -f "${DESTINO}/command-os/build/x86/instalar.sh" ]] || die "$(m 'el instalador descargado está incompleto' 'the downloaded installer is incomplete')"
echo "==> $(m 'Instalador' 'Installer') $(cat "${DESTINO}/command-os/PUBLICADO" 2>/dev/null || echo '?')"
# exec no pasa por el trap: se limpia antes (el agente de gpg y la carpeta temporal).
gpgconf --kill gpg-agent 2>/dev/null || true
rm -rf "${tmp}"
trap - EXIT
exec bash "${DESTINO}/command-os/build/x86/instalar.sh" "$@"
