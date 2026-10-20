#!/bin/bash
# Lanza en el Arch de WSL las mismas pruebas que la CI (.github/workflows/pruebas.yml):
# scripts, marca, pantallas, barra, aplicaciones, instalador, discos y rollback.
# Correr como root (usa discos loop y btrfs):
#   wsl -d archlinux -u root -- bash /mnt/c/<ruta al repo>/build/wsl/pruebas.sh [prueba...]
# Sin argumentos lanza todas; con nombres (p. ej. «marca rollback») solo esas.
# No lanza las del escritorio (escritorio, cuentas, idioma, zona-horaria, actualizaciones): necesitan
# el paquete command-os instalado y crean cuentas; esas corren solo en la CI (docs/testing.md).
# Falta una herramienta → la prueba se marca «saltada» y el resultado final no es limpio.
cd "$(dirname "$0")/../.." || exit 1

[ "$(id -u)" = 0 ] || { echo "correr como root: wsl -d archlinux -u root -- bash $0" >&2; exit 1; }

# El repo vive en /mnt/c (dueño distinto): git lo rechazaría sin esto. Solo para este proceso.
export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0='*'

PRUEBAS="scripts marca pantallas barra aplicaciones instalador discos rollback"
SELECCION=${*:-$PRUEBAS}

declare -A DEPENDE=(
  [scripts]="shellcheck"
  [instalador]="msgfmt git"
  [discos]="sgdisk mkfs.fat mkntfs cryptsetup busybox msgfmt losetup"
  [rollback]="btrfs mkfs.btrfs busybox losetup"
)
RESULTADO=()
LIMPIO=1

scripts() {
  local f
  for f in os/install.sh os/lib/* os/bin/* os/initcpio/*/* os/system/sleep-* os/pkg/PKGBUILD build/x86/*.sh tests/*.sh; do
    [ -f "$f" ] || continue # un __pycache__ local no existe en la CI
    case "$f" in
      *.py) python3 -c "import ast, sys; ast.parse(open(sys.argv[1]).read())" "$f" || return 1 ;;
      *) bash -n "$f" || return 1 ;;
    esac
  done
  # shellcheck disable=SC2046
  shellcheck -S error -e SC1090,SC1091 os/install.sh $(find os/lib -maxdepth 1 -type f ! -name '*.py') \
    os/bin/* os/initcpio/*/* os/system/sleep-* build/x86/*.sh tests/*.sh
}
marca() { bash tests/marca.sh; }
pantallas() { bash tests/pantallas.sh; }
barra() { bash tests/barra.sh; }
aplicaciones() { bash tests/aplicaciones.sh; }
instalador() { bash tests/instalador.sh; }
discos() { bash tests/discos.sh; }
rollback() { modprobe btrfs 2>/dev/null || true; bash tests/rollback.sh; }

for p in $SELECCION; do
  if ! declare -F "$p" >/dev/null || ! grep -qw "$p" <<<"$PRUEBAS"; then
    echo "prueba desconocida: $p (las hay: $PRUEBAS)" >&2; exit 2
  fi
  faltan=
  for h in ${DEPENDE[$p]}; do command -v "$h" >/dev/null || faltan="$faltan $h"; done
  if [ -n "$faltan" ]; then
    echo "== $p: SALTADA, faltan:$faltan (pacman -S --needed gptfdisk dosfstools ntfsprogs cryptsetup busybox btrfs-progs gettext shellcheck)"
    RESULTADO+=("saltada  $p"); LIMPIO=0; continue
  fi
  echo "== $p"
  if "$p"; then RESULTADO+=("bien     $p"); else RESULTADO+=("FALLA    $p"); LIMPIO=0; fi
done

echo; echo "== Resumen"; printf '%s\n' "${RESULTADO[@]}"
[ "$LIMPIO" = 1 ] && echo "Todo en verde." || echo "Hay pruebas fallidas o saltadas."
[ "$LIMPIO" = 1 ]
