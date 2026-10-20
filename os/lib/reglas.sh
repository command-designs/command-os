# Command OS — reglas de las cuentas que comparten los programas de shell (crear-cuenta,
# gestionar-cuentas, gestionar-disco). La copia en Python es lib/comun.py (MIN_CONTRASENA, USUARIO_ER):
# si se cambia una, se cambia la otra; tests/cuentas.sh comprueba que coinciden.
#   source "$(dirname "${BASH_SOURCE[0]}")/reglas.sh"
MIN_CONTRASENA=8

# usuario_valido NOMBRE — nombres de usuario de Linux: minúsculas, números, - y _, empezando por letra
# (máx. 32).
usuario_valido() { [[ "$1" =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; }

# contrasena_corta CLAVE — verdadero si no llega a la longitud mínima (en caracteres: sin un locale
# UTF-8, como en una sesión sin LANG, ${#1} contaría bytes y una ñ valdría por dos).
contrasena_corta() { local LC_ALL=C.UTF-8; (( ${#1} < MIN_CONTRASENA )); }
