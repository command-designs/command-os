#!/usr/bin/env bash
# Command OS — mantenimiento de las traducciones (docs/idioma.md).
#
#   bash build/po.sh            saca los textos de las fuentes y pone al día os/po/*.po (msgmerge):
#                               los textos nuevos quedan vacíos para traducirlos y los cambiados,
#                               «fuzzy» (hay que revisarlos y quitarles la marca)
#   bash build/po.sh comprobar  falla si algún texto no está traducido, está «fuzzy» o sobra
#                               (lo usa tests/idioma.sh)
#
# El texto original es el castellano (msgid). Necesita gettext (xgettext, msgmerge, msgfmt).
set -euo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
PO="${REPO}/os/po"
# Archivos con textos traducibles: Python con _() y N_(); bash con t (crear-cuenta, apply-boot).
PYTHON=(os/lib/greeter.py os/lib/primer-arranque.py)
SHELL_=(os/lib/crear-cuenta os/lib/apply-boot)

plantilla() {  # plantilla SALIDA.pot
  cd "${REPO}"
  xgettext --from-code=UTF-8 --no-location -L Python -k_ -kN_ -o "$1" "${PYTHON[@]}"
  xgettext --from-code=UTF-8 --no-location -j -L Shell -k -kt -o "$1" "${SHELL_[@]}"
  # Cabecera en UTF-8 y sin la fecha: msgmerge la copiaría al .po y cambiaría en cada pasada.
  sed -i -e 's/charset=CHARSET/charset=UTF-8/' -e '/^"POT-Creation-Date:/d' "$1"
}

pot=$(mktemp --suffix=.pot)
trap 'rm -f "${pot}"' EXIT
plantilla "${pot}"

case "${1:-}" in
  "")
    for f in "${PO}"/*.po; do
      msgmerge --quiet --update --backup=none --no-location "${f}" "${pot}"
      echo "${f#"${REPO}/"}: $(msgfmt --statistics -o /dev/null "${f}" 2>&1)"
    done ;;
  comprobar)
    fallos=0
    for f in "${PO}"/*.po; do
      nombre=${f#"${REPO}/"}
      msgfmt --check -o /dev/null "${f}" || { echo "${nombre}: no compila"; fallos=1; }
      # msgcmp: cada texto de las fuentes tiene que estar en el .po.
      if ! msgcmp --use-untranslated "${f}" "${pot}"; then
        echo "${nombre}: faltan textos de las fuentes (bash build/po.sh y traducirlos)"; fallos=1
      fi
      if [[ -n "$(msgattrib --untranslated --no-obsolete "${f}" | grep '^msgid ' | grep -v '^msgid ""$')" ]]; then
        echo "${nombre}: hay textos sin traducir (bash build/po.sh y traducirlos)"; fallos=1
      fi
      if [[ -n "$(msgattrib --only-fuzzy --no-obsolete "${f}")" ]]; then
        echo "${nombre}: hay traducciones «fuzzy» por revisar"; fallos=1
      fi
      # Al revés: textos que ya no están en las fuentes (sobran; build/po.sh los marca obsoletos).
      if [[ -n "$(msgcomm --less-than=2 --unique "${f}" "${pot}" 2>/dev/null | grep '^msgid ' | grep -v '^msgid ""$')" ]]; then
        echo "${nombre}: hay textos que ya no se usan (bash build/po.sh)"; fallos=1
      fi
    done
    exit "${fallos}" ;;
  *) echo "uso: bash build/po.sh [comprobar]" >&2; exit 2 ;;
esac
