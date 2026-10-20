#!/usr/bin/env bash
# Command OS — prueba de command-os-rollback (docs/actualizaciones.md § 5) sobre un btrfs de verdad en un
# disco loop: la raíz (@), las instantáneas (@snapshots/N/snapshot) y, en un caso, /boot en otra
# partición. Comprueba qué se queda como sistema, que /boot recibe el kernel de la instantánea, que
# si algo falla el sistema queda como estaba y que lo cancelado o inválido no toca nada. El último
# escenario usa los subvolúmenes del instalador (btrfs_root de build/x86/lib.sh): las apps de la tienda
# (@flatpak) no entran en las instantáneas ni vuelven atrás.
#
# El script actúa sobre rutas del sistema en marcha; aquí se le apuntan a la prueba con
# COMMAND_OS_LIB, COMMAND_OS_SNAPSHOTS y COMMAND_OS_BOOT. La raíz de la prueba lleva un busybox
# estático y un pacman y un mkinitcpio de mentira (para el chroot de restore_kernel).
#
# Necesita root, losetup, btrfs-progs, mkfs.ext4 y un busybox estático (busybox-static en Ubuntu).
# Solo toca discos loop sobre archivos temporales. Lo ejecuta GitHub Actions (pruebas.yml).
set -uo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
ROLLBACK="${REPO}/os/bin/command-os-rollback"
fallos=0
ok() { echo "  ok   $*"; }
mal() { echo "  MAL  $*"; fallos=$((fallos + 1)); }
[[ $(id -u) -eq 0 ]] || { echo "ejecutar como root" >&2; exit 1; }
for c in btrfs mkfs.btrfs losetup mkfs.ext4 busybox; do
  command -v "${c}" >/dev/null || { echo "falta ${c}" >&2; exit 1; }
done
BB=$(command -v busybox)
if ldd "${BB}" >/dev/null 2>&1; then echo "el busybox tiene que ser estático (busybox-static)" >&2; exit 1; fi

T=$(mktemp -d)
LOOPS=()
cleanup() {
  desmontar
  rm -rf "${T}"
}
trap cleanup EXIT

desmontar() {
  local l
  [[ -n "${BASE:-}" ]] && mountpoint -q "${BASE}/mnt" && umount -R "${BASE}/mnt"
  for l in "${BASE:-}/boot" "${BASE:-}/snap" "${BASE:-}/top"; do
    [[ "${l}" == /* ]] && mountpoint -q "${l}" && umount "${l}"
  done
  for l in "${LOOPS[@]}"; do losetup -d "${l}" 2>/dev/null; done
  LOOPS=()
}

# crear [boot] — btrfs nuevo, en un directorio nuevo por escenario (${BASE}), con la raíz «actual» (@),
# la instantánea 1 («vieja», con otro kernel) y el /boot de la prueba: una partición ext4 aparte con
# «boot», o un directorio normal sin él.
N=0
crear() {
  desmontar
  local dev bdev
  N=$((N + 1))
  BASE="${T}/s${N}"
  R="${BASE}/top/@"
  SNAP1="${BASE}/top/@snapshots/1/snapshot"
  SNAPS="${BASE}/snap"
  BOOT="${BASE}/boot"
  mkdir -p "${BASE}/top" "${BASE}/snap" "${BASE}/boot"
  truncate -s 700M "${BASE}/b.img"
  dev=$(losetup --find --show "${BASE}/b.img"); LOOPS+=("${dev}")
  mkfs.btrfs -q -f "${dev}"
  mount -o subvolid=5 "${dev}" "${BASE}/top"
  btrfs subvolume create "${R}" >/dev/null
  btrfs subvolume create "${BASE}/top/@snapshots" >/dev/null
  mkdir -p "${R}"/{bin,usr/bin,dev,proc,sys,boot/grub,usr/lib/modules/6.1.0-test}
  cp "${BB}" "${R}/bin/busybox"
  ln -s busybox "${R}/bin/sh"
  printf '#!/bin/sh\nexit 0\n' > "${R}/usr/bin/pacman"
  cat > "${R}/usr/bin/mkinitcpio" <<'EOF'
#!/bin/sh
# De mentira: escribe en -g el initramfs de la versión -k, y falla si existe /fallar.
[ -e /fallar ] && exit 1
while [ $# -gt 0 ]; do
  case "$1" in -k) v=$2; shift ;; -g) f=$2; shift ;; esac
  shift
done
printf 'initramfs de %s\n' "${v}" > "${f}"
EOF
  chmod +x "${R}/usr/bin/pacman" "${R}/usr/bin/mkinitcpio"
  # El estado «viejo», que será la instantánea 1 (con el kernel 6.1.0).
  echo viejo > "${R}/marker"
  echo grub-viejo > "${R}/boot/grub/grub.cfg"
  echo kernel-viejo > "${R}/usr/lib/modules/6.1.0-test/vmlinuz"
  echo linux > "${R}/usr/lib/modules/6.1.0-test/pkgbase"
  mkdir -p "${BASE}/top/@snapshots/1"
  btrfs subvolume snapshot "${R}" "${SNAP1}" >/dev/null
  # El sistema «actual»: otro estado, con un kernel más nuevo (6.2.0).
  echo actual > "${R}/marker"
  echo grub-actual > "${R}/boot/grub/grub.cfg"
  rm -r "${R}/usr/lib/modules/6.1.0-test"
  mkdir "${R}/usr/lib/modules/6.2.0-test"
  echo kernel-nuevo > "${R}/usr/lib/modules/6.2.0-test/vmlinuz"
  echo linux > "${R}/usr/lib/modules/6.2.0-test/pkgbase"
  mount -o subvol=@snapshots "${dev}" "${BASE}/snap"
  if [[ "${1:-}" == boot ]]; then
    truncate -s 64M "${BASE}/boot.img"
    bdev=$(losetup --find --show "${BASE}/boot.img"); LOOPS+=("${bdev}")
    mkfs.ext4 -q "${bdev}"
    mount "${bdev}" "${BASE}/boot"
  fi
  mkdir -p "${BOOT}/grub"
  echo grub-boot > "${BOOT}/grub/grub.cfg"
  echo kernel-nuevo > "${BOOT}/vmlinuz-linux"
  echo initramfs-nuevo > "${BOOT}/initramfs-linux.img"
  echo fallback-nuevo > "${BOOT}/initramfs-linux-fallback.img"
}

# correr ARGS… — ejecuta command-os-rollback con la confirmación $CONFIRMA (SI); deja la salida en
# $SALIDA y el código en $RC. LC_ALL=C: sin catálogo de traducciones sale el castellano original.
CONFIRMA=SI
correr() {
  SALIDA=$(printf '%s\n' "${CONFIRMA}" | COMMAND_OS_LIB="${REPO}/os/lib" COMMAND_OS_SNAPSHOTS="${SNAPS}" \
    COMMAND_OS_BOOT="${BOOT}" LANGUAGE= LC_ALL=C bash "${ROLLBACK}" "$@" 2>&1)
  RC=$?
  CONFIRMA=SI
}
copias() { find "${BASE}/top" -maxdepth 1 -name '@antes-de-volver-*' | head -5; }
contenido() { cat "$1" 2>/dev/null; }
es() { [[ "$(contenido "$1")" == "$2" ]]; }
# comprobar DESCRIPCIÓN COMANDO… — ok si el comando sale con 0.
comprobar() { local d=$1; shift; if "$@"; then ok "${d}"; else mal "${d}"; fi; }
rc_cero() { (( RC == 0 )); }
rc_error() { (( RC != 0 )); }
dice() { grep -q -- "$1" <<< "${SALIDA}"; }
# Nada cambió: la raíz sigue siendo la actual, sin copias ni restos, y /boot como estaba.
intacto() {
  comprobar "$1: la raíz sigue siendo la actual" es "${R}/marker" actual
  comprobar "$1: no queda ninguna copia ni resto" test -z "$(copias)"
  comprobar "$1: el kernel de /boot sigue igual" es "${BOOT}/vmlinuz-linux" kernel-nuevo
  comprobar "$1: el initramfs de /boot sigue igual" es "${BOOT}/initramfs-linux.img" initramfs-nuevo
  comprobar "$1: sin archivos .nuevo en /boot" test -z "$(find "${BOOT}" -name '*.nuevo')"
}

echo "==> Sin /boot aparte (el /boot/grub del sistema anterior pasa al recuperado)"
crear
correr 1
comprobar "sale con 0" rc_cero
comprobar "avisa de que está hecho" dice 'Hecho.'
comprobar "la raíz nueva es la instantánea (marca «viejo»)" es "${R}/marker" viejo
copia=$(copias)
comprobar "el sistema anterior queda guardado como @antes-de-volver-…" es "${copia}/marker" actual
comprobar "el /boot/grub es el del sistema anterior (no el de la instantánea)" es "${R}/boot/grub/grub.cfg" grub-actual
comprobar "la instantánea no se toca" es "${SNAP1}/marker" viejo
comprobar "sin /boot aparte no se toca el kernel de /boot" es "${BOOT}/vmlinuz-linux" kernel-nuevo

echo "==> Con /boot aparte (el kernel de la instantánea vuelve a /boot)"
crear boot
correr 1
comprobar "sale con 0" rc_cero
comprobar "la raíz nueva es la instantánea" es "${R}/marker" viejo
comprobar "/boot recibe el kernel de la instantánea" es "${BOOT}/vmlinuz-linux" kernel-viejo
comprobar "su initramfs se rehace con la versión de la instantánea" es "${BOOT}/initramfs-linux.img" 'initramfs de 6.1.0-test'
comprobar "el initramfs de reserva también" es "${BOOT}/initramfs-linux-fallback.img" 'initramfs de 6.1.0-test'
comprobar "sin archivos .nuevo en /boot" test -z "$(find "${BOOT}" -name '*.nuevo')"
comprobar "el /boot/grub de la partición no se toca" es "${BOOT}/grub/grub.cfg" grub-boot
comprobar "el /boot/grub de la raíz es el de la instantánea (GRUB no está ahí)" es "${R}/boot/grub/grub.cfg" grub-viejo

echo "==> Con /boot aparte y el mismo kernel"
crear boot
echo kernel-viejo > "${BOOT}/vmlinuz-linux"
echo initramfs-previo > "${BOOT}/initramfs-linux.img"
correr 1
comprobar "sale con 0" rc_cero
comprobar "dice que es el mismo kernel" dice 'es el mismo que hay en /boot'
comprobar "no rehace el initramfs" es "${BOOT}/initramfs-linux.img" initramfs-previo

echo "==> Si algo falla, todo vuelve a como estaba"
crear boot
touch "${SNAP1}/fallar"
correr 1
comprobar "sale con error" rc_error
comprobar "cuenta que lo deja como estaba" dice 'se deja el sistema como estaba'
intacto "fallo del initramfs"
comprobar "fallo del initramfs: la instantánea sigue ahí" es "${SNAP1}/marker" viejo
comprobar "fallo del initramfs: el fallback de /boot sigue igual" es "${BOOT}/initramfs-linux-fallback.img" fallback-nuevo

echo "==> Cancelado, entradas inválidas y sin instantáneas"
crear boot
CONFIRMA=NO correr 1
comprobar "otra palabra que la de confirmación: sale con error" rc_error
comprobar "otra palabra que la de confirmación: dice cancelado" dice 'cancelado'
intacto "cancelado"
correr 99
comprobar "instantánea que no existe: sale con error" rc_error
comprobar "instantánea que no existe: lo dice" dice 'no existe la instantánea'
intacto "instantánea inexistente"
correr abc
comprobar "argumento que no es un número: sale con error" rc_error
comprobar "argumento que no es un número: muestra el uso" dice 'uso: command-os-rollback'
intacto "argumento inválido"
umount "${BASE}/snap"
correr 1
comprobar "sin /.snapshots: sale con error" rc_error
comprobar "sin /.snapshots: avisa de que no hay instantáneas" dice 'no hay instantáneas'
intacto "sin instantáneas"

echo "==> Con los subvolúmenes del instalador (btrfs_root): las apps de la tienda no vuelven atrás"
# El btrfs_root de verdad (build/x86/lib.sh), montado en ${M} como lo deja el instalador, con una
# instantánea de @ de solo lectura, como las de snapper. Sin /boot aparte.
desmontar
N=$((N + 1))
BASE="${T}/s${N}"
M="${BASE}/mnt"
R="${BASE}/top/@"
SNAPS="${M}/.snapshots"
BOOT="${BASE}/boot"
mkdir -p "${M}" "${BASE}/top" "${BOOT}"
truncate -s 700M "${BASE}/b.img"
dev=$(losetup --find --show "${BASE}/b.img"); LOOPS+=("${dev}")
# shellcheck source=../build/x86/lib.sh
( export COMMAND_OS_LOCALE_DIR="${T}/locale"; source "${REPO}/build/x86/lib.sh" && btrfs_root "${dev}" "${M}" )
mount -o subvolid=5 "${dev}" "${BASE}/top"
subvolumen() { btrfs subvolume show "$1" >/dev/null 2>&1; }
for sv in @ @home @snapshots @var_log @pkg @flatpak; do
  comprobar "crea el subvolumen ${sv}" subvolumen "${BASE}/top/${sv}"
done
montado_de() { [[ "$(findmnt -no FSROOT "$1")" == "$2" ]]; }
comprobar "/var/lib/flatpak se monta desde @flatpak" montado_de "${M}/var/lib/flatpak" /@flatpak
echo viejo > "${M}/marker"
echo app-vieja > "${M}/var/lib/flatpak/app"
mkdir -p "${SNAPS}/1"
btrfs subvolume snapshot -r "${M}" "${SNAPS}/1/snapshot" >/dev/null
echo actual > "${M}/marker"
echo app-nueva > "${M}/var/lib/flatpak/app"
comprobar "la instantánea no lleva las apps (solo la carpeta vacía)" \
  test -d "${SNAPS}/1/snapshot/var/lib/flatpak" -a ! -e "${SNAPS}/1/snapshot/var/lib/flatpak/app"
correr 1
comprobar "sale con 0" rc_cero
comprobar "la raíz nueva es la instantánea" es "${R}/marker" viejo
comprobar "las apps siguen como estaban (@flatpak no vuelve atrás)" es "${BASE}/top/@flatpak/app" app-nueva
comprobar "la raíz nueva no trae apps dentro de @" test ! -e "${R}/var/lib/flatpak/app"

echo
if (( fallos )); then echo "==> ${fallos} fallo(s)"; exit 1; fi
echo "==> todo bien"
