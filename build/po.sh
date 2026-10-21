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
# Archivos con textos traducibles: Python con _() y N_(); shell con t y tn (lib/textos.sh).
PYTHON=(os/lib/greeter.py os/lib/primer-arranque.py os/lib/zonas.py os/lib/selector_zona.py os/lib/ajustes.py os/lib/ajustes_actualizaciones.py os/lib/ajustes_cuentas.py os/lib/ajustes_disco.py os/lib/ajustes_bateria.py os/lib/ajustes_idioma.py os/lib/ajustes_red.py os/lib/ajustes_bluetooth.py os/lib/ajustes_barra.py os/lib/ajustes_pantalla.py os/lib/ajustes_sonido.py os/lib/ajustes_fondo.py os/lib/ajustes_sistema.py os/lib/redes.py os/lib/bateria.py os/lib/fijadas.py os/lib/clave-wifi.py os/lib/abrir-descarga.py os/lib/comun.py build/make-plymouth-textos.py)
SHELL_=(
  os/install.sh os/lib/crear-cuenta os/lib/apply-boot
  os/bin/command-os-{about,captura,clipboard,desktops,estado,idioma,keys,launcher,lock,login,power,rollback,status,update,updates,wallpaper,wifi,zona-horaria}
  build/x86/{instalar,lib,install-disco,install-dualboot}.sh
)
# Archivos de configuración que no pueden llamar a gettext (lib/traducir.py, docs/idioma.md): los
# textos entre {{ }}, y las etiquetas label="…" de los menús de labwc.
MARCAS=(os/dotfiles/waybar/config.jsonc os/dotfiles/hypr/hyprlock.conf os/dotfiles/hypr/hyprlock-emergencia.conf)
ETIQUETAS=(os/dotfiles/labwc/menu.xml)

# Los textos de SHELL_, MARCAS y ETIQUETAS como un Python de _("…") y ngettext(…), para que xgettext
# los trate igual. En shell se buscan las llamadas `t 'texto'` y `tn 'singular' 'plural' N` con los
# textos escritos enteros entre comillas (xgettext -L Shell se pierde tras `{`, `do` o `(( ))`).
estaticos() {
  python3 - "$@" <<'EOF'
import json, re, sys
sys.dont_write_bytecode = True
sys.path.insert(0, "os/lib")
import traducir

LIT = r"""(?:'([^']*)'|"([^"$`\x5c]*)")"""
SHELL_T = re.compile(r"(?<![\w-])t\s+" + LIT)
SHELL_TN = re.compile(r"(?<![\w-])tn\s+" + LIT + r"\s+" + LIT)
NO_LITERAL = re.compile(r"""(?<![\w-])tn?\s+["']?\$""")
j = lambda s: json.dumps(s, ensure_ascii=False)
pick = lambda a, b: a if a else b
modo, fallos = None, 0
for arg in sys.argv[1:]:
    if arg in ("shell", "marcas", "etiquetas"):
        modo = arg
        continue
    texto = open(arg, encoding="utf-8").read()
    if modo == "shell":
        for n, linea in enumerate(texto.splitlines(), 1):
            if linea.lstrip().startswith("#"):
                continue
            if NO_LITERAL.search(linea):
                print(f"{arg}:{n}: texto sin escribir entero: {linea.strip()}", file=sys.stderr)
                fallos = 1
            for m in SHELL_TN.finditer(linea):
                print("ngettext(%s, %s, 1)" % (j(pick(m[1], m[2])), j(pick(m[3], m[4]))))
            for m in SHELL_T.finditer(linea):
                print("_(%s)" % j(pick(m[1], m[2])))
    else:
        regex = traducir.MARCA if modo == "marcas" else traducir.ETIQUETA
        for m in regex.finditer(texto):
            original = m.group(1) if modo == "marcas" else traducir.unescape(m.group(2))
            print("_(%s)" % j(original))
sys.exit(fallos)
EOF
}

plantilla() {  # plantilla SALIDA.pot
  cd "${REPO}"
  xgettext --from-code=UTF-8 --no-location -L Python -k_ -kN_ -o "$1" "${PYTHON[@]}"
  local estaticos
  estaticos=$(mktemp --suffix=.py)
  estaticos shell "${SHELL_[@]}" marcas "${MARCAS[@]}" etiquetas "${ETIQUETAS[@]}" > "${estaticos}" \
    || { rm -f "${estaticos}"; exit 1; }
  xgettext --from-code=UTF-8 --no-location -j -L Python -k_ -o "$1" "${estaticos}"
  rm -f "${estaticos}"
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
    # Un script que carga textos.sh y no está en SHELL_ no saca sus textos: saldrían sin traducir.
    cd "${REPO}"
    for f in $(grep -slE '^\s*(source|\.)\s+\S*textos\.sh' os/install.sh os/bin/* os/lib/* build/x86/*.sh); do
      [[ " ${SHELL_[*]} " == *" ${f} "* ]] || { echo "${f}: usa textos.sh y no está en SHELL_ (build/po.sh)"; fallos=1; }
    done
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
