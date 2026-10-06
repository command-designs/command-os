# shellcheck shell=bash
# Command OS — funciones comunes de los instaladores x86 (build-image.sh, install-dualboot.sh).
# Se cargan con `source`.

# Opciones de montaje de btrfs: compresión ligera (menos escritura en USB/SSD) y sin atime.
BTRFS_OPTS=noatime,compress=zstd:1

# btrfs_root DISPOSITIVO PUNTO_DE_MONTAJE — formatea en btrfs y monta los subvolúmenes:
#   @           /                      el sistema: lo que guardan las instantáneas
#   @home       /home                  archivos del usuario: no retroceden al volver atrás
#   @snapshots  /.snapshots            instantáneas de snapper (install.sh configura snapper)
#   @var_log    /var/log               registros: se conservan al volver atrás (ver qué pasó)
#   @pkg        /var/cache/pacman/pkg  caché de paquetes: no hace falta fotografiarla
# El kernel va en /boot dentro de @: una instantánea guarda el kernel con sus módulos.
btrfs_root() {
  local dev=$1 mnt=$2 sv
  mkfs.btrfs -f -L command-os "${dev}" >/dev/null
  mount "${dev}" "${mnt}"
  for sv in @ @home @snapshots @var_log @pkg; do
    btrfs subvolume create "${mnt}/${sv}" >/dev/null
  done
  umount "${mnt}"
  mount -o "${BTRFS_OPTS},subvol=@" "${dev}" "${mnt}"
  mkdir -p "${mnt}"/{home,.snapshots,var/log,var/cache/pacman/pkg}
  mount -o "${BTRFS_OPTS},subvol=@home" "${dev}" "${mnt}/home"
  mount -o "${BTRFS_OPTS},subvol=@snapshots" "${dev}" "${mnt}/.snapshots"
  mount -o "${BTRFS_OPTS},subvol=@var_log" "${dev}" "${mnt}/var/log"
  mount -o "${BTRFS_OPTS},subvol=@pkg" "${dev}" "${mnt}/var/cache/pacman/pkg"
}

# fstab MONTAJE — genfstab sin swap y sin subvolid: los subvolúmenes se montan por nombre, así que
# command-os-rollback puede sustituir @ por una instantánea (cambia el id, no el nombre).
fstab() {
  genfstab -U "$1" | grep -vw swap | sed -E 's/,subvolid=[0-9]+//' >> "$1/etc/fstab"
}

# pinned_pacman_conf REPO — pacman.conf temporal para pacstrap con el Arch de la fecha validada
# (os/pacman/snapshot-date): el sistema nuevo nace con los mismos paquetes que se han probado.
# Imprime la ruta. ROLLING=1 usa los espejos del día.
pinned_pacman_conf() {
  local repo=$1 date conf mirror
  conf=$(mktemp) mirror=$(mktemp)
  date=$(grep -oE '^[0-9]{4}/[0-9]{2}/[0-9]{2}' "${repo}/os/pacman/snapshot-date" | head -1)
  if [[ -n "${date}" && -z "${ROLLING:-}" ]]; then
    echo "Server = https://archive.archlinux.org/repos/${date}/\$repo/os/\$arch" > "${mirror}"
  else
    cp /etc/pacman.d/mirrorlist "${mirror}"
  fi
  sed "s|^Include = /etc/pacman.d/mirrorlist$|Include = ${mirror}|" /etc/pacman.conf > "${conf}"
  echo "${conf}"
}
