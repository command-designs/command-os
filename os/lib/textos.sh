# shellcheck shell=sh
# Command OS — traducciones para los scripts de shell (docs/idioma.md). Se carga con
#   . /usr/lib/command-os/textos.sh
# Vale para bash y para sh. El texto original es el castellano: sin catálogo para el idioma, sale
# tal cual. Los textos van siempre enteros (nunca montados a trozos) para que build/po.sh los encuentre.
export TEXTDOMAIN=command-os TEXTDOMAINDIR=/usr/share/locale

# t 'texto con %s' ARGS… — el texto traducido, con los datos puestos (printf), sin salto de línea.
t() {
  _t_f=$1
  shift
  _t_x=$(gettext -- "${_t_f}" 2>/dev/null) && _t_f=${_t_x}
  # shellcheck disable=SC2059  # el formato es el texto traducido
  printf -- "${_t_f}" "$@"
}

# tn 'un paquete' '%d paquetes' N ARGS… — singular o plural según N (la regla de cada idioma está en
# su catálogo), con ARGS puestos con printf (normalmente N).
tn() {
  _t_s=$1 _t_p=$2 _t_n=$3
  shift 3
  if _t_x=$(ngettext -- "${_t_s}" "${_t_p}" "${_t_n}" 2>/dev/null); then
    _t_f=${_t_x}
  elif [ "${_t_n}" -eq 1 ]; then
    _t_f=${_t_s}
  else
    _t_f=${_t_p}
  fi
  # shellcheck disable=SC2059
  printf -- "${_t_f}" "$@"
}
