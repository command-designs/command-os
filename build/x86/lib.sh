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

# ---------------------------------------------------------------------------------------------
# Instalación en el disco del equipo (install-dualboot.sh, install-disco.sh). build-image.sh hace
# una imagen genérica para cualquier equipo y no usa estas funciones.
# ---------------------------------------------------------------------------------------------

declare -F die >/dev/null || die() { echo "error: $*" >&2; exit 1; }

# require_live_usb — los instaladores al disco solo corren desde el USB en vivo de Arch: así nunca
# se lanzan por error en un equipo ya instalado (el PC de desarrollo, por ejemplo).
# COMMAND_OS_FUERA_DEL_USB=1 lo salta (solo para pruebas en una VM).
require_live_usb() {
  [[ -d /run/archiso || -n "${COMMAND_OS_FUERA_DEL_USB:-}" ]] \
    || die "esto se ejecuta desde el USB en vivo de Arch Linux, no desde un sistema instalado"
}

# detect_variant — si no se eligió variante (VARIANT sin definir), pc-nvidia con GPU NVIDIA.
detect_variant() {
  if [[ -z "${VARIANT+x}" ]]; then
    VARIANT=
    if lspci 2>/dev/null | grep -qiE '(vga|3d|display).*nvidia'; then VARIANT=pc-nvidia; fi
  fi
  echo "==> Variante: ${VARIANT:-ninguna (GPU Intel/AMD)}"
}

# install_base MONTAJE REPO [PAQUETES...] — sistema base con el Arch de la fecha validada, fstab y
# el árbol os/ listo para install.sh. El kernel y el initramfs van en /boot dentro de btrfs (entran
# en las instantáneas); la partición EFI solo recibe GRUB.
install_base() {
  local mnt=$1 repo=$2
  shift 2
  pacstrap -K -C "$(pinned_pacman_conf "${repo}")" "${mnt}" base linux linux-firmware intel-ucode \
    amd-ucode sudo networkmanager openssh grub efibootmgr btrfs-progs git base-devel "$@"
  fstab "${mnt}"
  mkdir -p "${mnt}/root/command-os-src" "${mnt}/etc/command-os"
  cp -r "${repo}/os" "${mnt}/root/command-os-src/os"
  find "${mnt}/root/command-os-src/os" -name '*.sh' -exec sed -i 's/\r$//' {} +
  echo "${KB_LAYOUT}" > "${mnt}/etc/command-os/kb_layout"
}

# forget_nvram_entries — borra de la NVRAM las entradas «command-os» de instalaciones anteriores.
# grub-install no actualiza una entrada que ya tiene su misma ruta (\EFI\command-os\grubx64.efi)
# aunque apunte a otra partición: al reinstalar (de dual boot a disco entero, u otro disco) la BIOS
# seguiría una entrada muerta y, en un dual boot, acabaría arrancando Windows sin menú.
forget_nvram_entries() {
  local n
  for n in $(efibootmgr 2>/dev/null | sed -nE 's/^Boot([0-9A-Fa-f]{4})\*? command-os([[:space:]].*)?$/\1/p'); do
    efibootmgr -q -b "${n}" -B || echo "aviso: no se pudo borrar la entrada UEFI vieja Boot${n}" >&2
  done
}

# configure_system MONTAJE EFI — idioma, teclado, zona, nombre, Command OS (os/install.sh) y GRUB.
#   EFI=compartida  la partición EFI es de Windows: GRUB en EFI/command-os, sin --removable (no se
#                   pisa EFI/BOOT/BOOTX64.EFI, el arranque de reserva de Windows).
#   EFI=propia      el disco es solo de Command OS: entrada en la NVRAM del equipo y, además, la
#                   copia de reserva EFI/BOOT/BOOTX64.EFI (arranca aunque el firmware pierda la entrada).
# NO_NVRAM=1 no toca la NVRAM (pruebas sobre un disco loop). Falla si la instalación no se completó.
configure_system() {
  local mnt=$1 efi=$2 grub="grub-install --target=x86_64-efi --efi-directory=/efi --boot-directory=/boot"
  local boot
  case "${efi}" in
    compartida) boot="${grub} --bootloader-id=command-os${NO_NVRAM:+ --no-nvram}" ;;
    propia)
      boot="${grub} --removable --no-nvram"
      if [[ -z "${NO_NVRAM:-}" ]]; then boot="${grub} --bootloader-id=command-os && ${boot}"; fi
      ;;
    *) die "configure_system: EFI desconocida: ${efi}" ;;
  esac
  if [[ -z "${NO_NVRAM:-}" ]]; then forget_nvram_entries; fi
  arch-chroot "${mnt}" /bin/bash -euxc "
    ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
    echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
    echo 'es_ES.UTF-8 UTF-8' >> /etc/locale.gen
    locale-gen
    echo 'LANG=en_US.UTF-8' > /etc/locale.conf
    echo 'KEYMAP=${KB_LAYOUT}' > /etc/vconsole.conf
    echo ${HOSTNAME_NEW} > /etc/hostname
    passwd -l root
    COMMAND_OS_VARIANT=${VARIANT} COMMAND_OS_SSH=${COMMAND_OS_SSH:-0} bash /root/command-os-src/os/install.sh
    if [[ '${VARIANT}' == pc-nvidia ]]; then
      grep -q 'nvidia_drm.modeset' /etc/default/grub || sed -i -E 's/^(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*)\"/\1 nvidia_drm.modeset=1 nvidia_drm.fbdev=1\"/' /etc/default/grub
    fi
    ${boot}
    grub-mkconfig -o /boot/grub/grub.cfg
  "
  # Comprobación explícita: una instalación a medias no debe darse por buena.
  [[ -f "${mnt}/usr/share/command-os/version" && -f "${mnt}/boot/grub/grub.cfg" ]] \
    || die "la instalación no se completó (ver el registro de arriba)"
  if [[ "${efi}" == propia && ! -f "${mnt}/efi/EFI/BOOT/BOOTX64.EFI" ]]; then
    die "falta el arranque de reserva EFI/BOOT/BOOTX64.EFI"
  fi
  rm -rf "${mnt}/root/command-os-src"
}

# --- Seguridad del disco (instalar en disco entero lo borra: tests/discos.sh lo prueba) ---

# part_path DISCO N — ruta de la partición N: /dev/sda1, pero /dev/nvme0n1p1, /dev/mmcblk0p1, /dev/loop0p1.
part_path() {
  if [[ "$1" =~ [0-9]$ ]]; then echo "$1p$2"; else echo "$1$2"; fi
}

# disk_of DISPOSITIVO — los discos de los que cuelga (partición, LUKS, LVM…): uno por línea.
disk_of() {
  lsblk -nrpso NAME,TYPE "$1" 2>/dev/null | awk '$2 == "disk" || $2 == "loop" { print $1 }'
}

# disk_problems DISCO — por qué NO se puede borrar este disco, una razón por línea (nada = se puede).
# COMMAND_OS_DISCOS_LOOP=1 admite discos loop (pruebas). MIN_GB: tamaño mínimo (30 por defecto).
disk_problems() {
  local disk=$1 type src d name
  if [[ ! -b "${disk}" ]]; then echo "${disk} no existe o no es un disco"; return 0; fi
  type=$(lsblk -dno TYPE "${disk}")
  if [[ "${type}" != disk && ! ( "${type}" == loop && -n "${COMMAND_OS_DISCOS_LOOP:-}" ) ]]; then
    case "${type}" in
      part) type="una partición" ;;
      rom) type="un lector de CD/DVD" ;;
      *) type="un dispositivo de tipo ${type:-desconocido}" ;;
    esac
    echo "${disk} es ${type}, no un disco entero (ejemplo: /dev/nvme0n1, no /dev/nvme0n1p2)"
    return 0
  fi
  [[ "$(lsblk -dno RO "${disk}" | tr -d ' ')" == 1 ]] && echo "${disk} es de solo lectura"
  if (( $(lsblk -dbno SIZE "${disk}") < ${MIN_GB:-30} * 1024 * 1024 * 1024 )); then
    echo "${disk} es demasiado pequeño (mínimo ${MIN_GB:-30} GB)"
  fi
  # El USB en vivo (aunque se haya copiado a la RAM, su etiqueta ARCH_AAAAMM sigue ahí) y el
  # disco del sistema en marcha.
  lsblk -nro LABEL "${disk}" | grep -q '^ARCH_' && echo "${disk} es el USB de instalación de Arch"
  for src in $(findmnt -nro SOURCE /run/archiso/bootmnt 2>/dev/null) $(findmnt -nro SOURCE / 2>/dev/null); do
    for d in $(disk_of "${src}"); do
      [[ "${d}" == "${disk}" ]] && echo "${disk} tiene el sistema que está en marcha"
    done
  done
  lsblk -nro MOUNTPOINTS "${disk}" | grep -q . \
    && echo "${disk} tiene particiones montadas: $(lsblk -nro MOUNTPOINTS "${disk}" | grep . | paste -sd ' ')"
  for src in $(swapon --show=NAME --noheadings 2>/dev/null); do
    for d in $(disk_of "${src}"); do
      [[ "${d}" == "${disk}" ]] && echo "${disk} tiene swap en uso (${src})"
    done
  done
  # Algo encima de alguna de sus particiones: LVM, RAID o un volumen cifrado abierto.
  for name in $(lsblk -nro NAME "${disk}"); do
    if [[ -n "$(ls -A "/sys/class/block/${name}/holders" 2>/dev/null)" ]]; then
      echo "${disk} está en uso (LVM, RAID o un volumen cifrado abierto en ${name})"
      break
    fi
  done
  return 0
}

# disk_has_windows DISCO — sale con 0 si parece tener Windows (NTFS, BitLocker, partición reservada
# de Microsoft o el gestor de arranque de Windows en la EFI).
disk_has_windows() {
  lsblk -nro FSTYPE,PARTTYPE "$1" 2>/dev/null \
    | grep -qiE '^(ntfs|bitlocker)|e3c9e316-0b5c-4db8-817d-f92df00215ae|de94bba4-06d1-4d40-a16a-bfd50179d6ac'
}

# confirm_erase DISCO — pide escribir el nombre exacto del disco (y, si tiene Windows, BORRAR
# WINDOWS). Sale con 0 solo si coincide todo: un Intro o un «sí» no borran nada.
confirm_erase() {
  local disk=$1 ok
  read -rp "Para borrarlo, escribe el nombre del disco (${disk}): " ok || return 1
  [[ "${ok}" == "${disk}" ]] || return 1
  if disk_has_windows "${disk}"; then
    read -rp "Este disco tiene Windows y se perderá. Escribe BORRAR WINDOWS para seguir: " ok || return 1
    [[ "${ok}" == "BORRAR WINDOWS" ]] || return 1
  fi
  return 0
}

# partition_whole_disk DISCO — borra la tabla y las firmas del disco y crea GPT con EFI de 1 GiB
# (tipo ef00) y el resto para Command OS (tipo 8304, raíz Linux x86-64). No formatea.
partition_whole_disk() {
  local disk=$1
  wipefs -aq "${disk}"
  sgdisk --zap-all "${disk}" >/dev/null
  sgdisk -n 1:0:+1G -t 1:ef00 -c 1:EFI -n 2:0:0 -t 2:8304 -c 2:command-os "${disk}" >/dev/null
  partprobe "${disk}" 2>/dev/null || true
  udevadm settle 2>/dev/null || sleep 2
  [[ -b "$(part_path "${disk}" 1)" && -b "$(part_path "${disk}" 2)" ]] \
    || die "no aparecieron las particiones nuevas de ${disk}"
}
