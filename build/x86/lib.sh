# shellcheck shell=bash
# Command OS — funciones comunes de los instaladores x86 (build-image.sh, install-dualboot.sh).
# Se cargan con `source`.

# Opciones de montaje de btrfs: compresión ligera (menos escritura en USB/SSD) y sin atime.
BTRFS_OPTS=noatime,compress=zstd:1
# Idioma de serie (docs/idioma.md): locale.conf y el menú de GRUB del instalador. Se cambia en el
# asistente de primer arranque o con command-os-idioma.
IDIOMA=es_ES.UTF-8

# btrfs_root DISPOSITIVO PUNTO_DE_MONTAJE — formatea en btrfs y monta los subvolúmenes:
#   @           /                      el sistema: lo que guardan las instantáneas
#   @home       /home                  archivos del usuario: no retroceden al volver atrás
#   @snapshots  /.snapshots            instantáneas de snapper (install.sh configura snapper)
#   @var_log    /var/log               registros: se conservan al volver atrás (ver qué pasó)
#   @pkg        /var/cache/pacman/pkg  caché de paquetes: no hace falta fotografiarla
# El kernel va en /boot dentro de @: una instantánea guarda el kernel con sus módulos. Con el disco
# cifrado, /boot es una partición aparte (boot_partition) y command-os-rollback repone el kernel.
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

# boot_partition DISPOSITIVO MONTAJE — con el disco cifrado: formatea /boot en ext4 (sin cifrar; GRUB
# lee de aquí el kernel, el initramfs y su tema) y lo monta en MONTAJE/boot. Va después de btrfs_root.
boot_partition() {
  mkfs.ext4 -q -F -L command-os-boot "$1"
  mkdir -p "$2/boot"
  mount "$1" "$2/boot"
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
# en las instantáneas) o, con el disco cifrado, en la partición /boot sin cifrar (GRUB no la
# descifra: la contraseña se pide en el splash); la partición EFI solo recibe GRUB.
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

# forget_nvram_entries DISCO — borra de la NVRAM las entradas «command-os» que ya no sirven: las que
# apuntan a una partición que no existe o a DISCO (el que se está instalando; grub-install pone la
# suya). grub-install no actualiza una entrada que ya tiene su misma ruta (\EFI\command-os\grubx64.efi)
# aunque apunte a otra partición: al reinstalar, la BIOS seguiría una entrada muerta y, en un dual
# boot, acabaría arrancando Windows sin menú. Se respeta la de otro Command OS en otro disco.
forget_nvram_entries() {
  local disk=$1 n guid dev d borrar
  while read -r n guid; do
    borrar=1
    # blkid sale con 2 si la partición no existe (justo el caso que se busca): con set -e y
    # pipefail cerraría el instalador sin decir nada.
    dev=$(blkid -t "PARTUUID=${guid}" -o device 2>/dev/null | head -1 || true)
    if [[ -n "${dev}" ]]; then
      for d in $(disk_of "${dev}"); do [[ "${d}" != "${disk}" ]] && borrar=0; done
    fi
    if (( borrar )); then
      efibootmgr -q -b "${n}" -B || echo "aviso: no se pudo borrar la entrada UEFI vieja Boot${n}" >&2
    fi
  done < <(efibootmgr -v 2>/dev/null \
    | sed -nE 's/^Boot([0-9A-Fa-f]{4})\*? command-os\t.*HD\([0-9]+,GPT,([0-9A-Fa-f-]+),.*/\1 \2/p')
}

# configure_system MONTAJE EFI DISCO — idioma, teclado, zona, nombre, Command OS (os/install.sh) y GRUB.
#   EFI=compartida  la partición EFI es de Windows: GRUB en EFI/command-os, sin --removable (no se
#                   pisa EFI/BOOT/BOOTX64.EFI, el arranque de reserva de Windows).
#   EFI=propia      el disco es solo de Command OS: entrada en la NVRAM del equipo y, además, la
#                   copia de reserva EFI/BOOT/BOOTX64.EFI (arranca aunque el firmware pierda la entrada).
# DISCO es el disco donde se instala (forget_nvram_entries). NO_NVRAM=1 no toca la NVRAM (pruebas
# sobre un disco loop). Falla si la instalación no se completó.
configure_system() {
  local mnt=$1 efi=$2 disk=$3 grub="grub-install --target=x86_64-efi --efi-directory=/efi --boot-directory=/boot"
  local boot luks cmdline=""
  # Raíz cifrada: cryptdevice= en GRUB_CMDLINE_LINUX (no en _DEFAULT, que es de apply-boot), así va
  # también en las entradas de recuperación y en las de las instantáneas (grub-btrfs).
  luks=$(luks_uuid_of "${mnt}")
  [[ -n "${luks}" ]] && cmdline="cryptdevice=UUID=${luks}:${LUKS_NAME}"
  case "${efi}" in
    compartida) boot="${grub} --bootloader-id=command-os${NO_NVRAM:+ --no-nvram}" ;;
    propia)
      boot="${grub} --removable --no-nvram"
      if [[ -z "${NO_NVRAM:-}" ]]; then boot="${grub} --bootloader-id=command-os && ${boot}"; fi
      ;;
    *) die "configure_system: EFI desconocida: ${efi}" ;;
  esac
  if [[ -z "${NO_NVRAM:-}" ]]; then forget_nvram_entries "${disk}"; fi
  arch-chroot "${mnt}" /bin/bash -euxc "
    ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime
    # Castellano de serie; inglés generado para poder elegirlo en el asistente (command-os-idioma).
    echo 'es_ES.UTF-8 UTF-8' >> /etc/locale.gen
    echo 'en_US.UTF-8 UTF-8' >> /etc/locale.gen
    locale-gen
    echo 'LANG=${IDIOMA}' > /etc/locale.conf
    echo 'KEYMAP=${KB_LAYOUT}' > /etc/vconsole.conf
    echo ${HOSTNAME_NEW} > /etc/hostname
    passwd -l root
    COMMAND_OS_VARIANT=${VARIANT} COMMAND_OS_SSH=${COMMAND_OS_SSH:-0} bash /root/command-os-src/os/install.sh
    if [[ '${VARIANT}' == pc-nvidia ]]; then
      grep -q 'nvidia_drm.modeset' /etc/default/grub || sed -i -E 's/^(GRUB_CMDLINE_LINUX_DEFAULT=\"[^\"]*)\"/\1 nvidia_drm.modeset=1 nvidia_drm.fbdev=1\"/' /etc/default/grub
    fi
    if [[ -n '${cmdline}' ]]; then
      sed -i -E '/^#?GRUB_CMDLINE_LINUX=/d' /etc/default/grub
      echo 'GRUB_CMDLINE_LINUX=\"${cmdline}\"' >> /etc/default/grub
    fi
    ${boot}
    LANG=${IDIOMA} grub-mkconfig -o /boot/grub/grub.cfg
  "
  # Comprobación explícita: una instalación a medias no debe darse por buena.
  [[ -f "${mnt}/usr/share/command-os/version" && -f "${mnt}/boot/grub/grub.cfg" ]] \
    || die "la instalación no se completó (ver el registro de arriba)"
  if [[ "${efi}" == propia && ! -f "${mnt}/efi/EFI/BOOT/BOOTX64.EFI" ]]; then
    die "falta el arranque de reserva EFI/BOOT/BOOTX64.EFI"
  fi
  # Cifrado: sin cryptdevice= en el menú o sin los ganchos en el initramfs, el equipo no arrancaría.
  if [[ -n "${luks}" ]]; then
    grep -q "cryptdevice=UUID=${luks}:${LUKS_NAME}" "${mnt}/boot/grub/grub.cfg" \
      || die "el menú de GRUB no abre el disco cifrado (falta cryptdevice=)"
    grep -qE '^HOOKS=.*\bcommand-os-cifrado encrypt\b' "${mnt}/etc/mkinitcpio.conf" \
      || die "el initramfs no tiene los ganchos del disco cifrado"
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
  local disk=$1 type src d name size target montajes
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
  # Si lsblk no da el tamaño, cuenta como 0: ante la duda, no se borra.
  size=$(lsblk -dbno SIZE "${disk}" 2>/dev/null | tr -d ' ')
  [[ "${size}" =~ ^[0-9]+$ ]] || size=0
  if (( size < ${MIN_GB:-30} * 1024 * 1024 * 1024 )); then
    echo "${disk} es demasiado pequeño (mínimo ${MIN_GB:-30} GB)"
  fi
  # El USB en vivo (aunque se haya copiado a la RAM, su etiqueta sigue ahí: ARCH_AAAAMM, o Ventoy) y
  # el disco del sistema en marcha.
  lsblk -nro LABEL "${disk}" | grep -qE '^(ARCH_|Ventoy$|VTOYEFI$)' && echo "${disk} es el USB de instalación de Arch"
  for src in $(findmnt -nro SOURCE /run/archiso/bootmnt 2>/dev/null) $(findmnt -nro SOURCE / 2>/dev/null); do
    for d in $(disk_of "${src}"); do
      [[ "${d}" == "${disk}" ]] && echo "${disk} tiene el sistema que está en marcha"
    done
  done
  # Montajes desde la tabla del núcleo (findmnt), no desde una columna de lsblk que puede faltar.
  # Un subvolumen de btrfs sale como /dev/sdb2[/@]: se quita lo de los corchetes.
  montajes=""
  while read -r src target; do
    src=${src%%\[*}
    [[ "${src}" == /dev/* ]] || continue
    for d in $(disk_of "${src}"); do
      [[ "${d}" == "${disk}" ]] && montajes+=" ${target}"
    done
  done < <(findmnt -rno SOURCE,TARGET)
  [[ -n "${montajes}" ]] && echo "${disk} tiene particiones montadas:${montajes}"
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

# partition_whole_disk DISCO [cifrado] — borra la tabla y las firmas del disco y crea GPT con EFI de
# 1 GiB (tipo ef00) y el resto para Command OS (tipo 8304, raíz Linux x86-64). Con «cifrado», entre
# las dos va /boot de 1 GiB sin cifrar (8300; GRUB lee de ahí el kernel) y el resto es LUKS (8309).
# No formatea.
partition_whole_disk() {
  local disk=$1 n=2
  wipefs -aq "${disk}"
  sgdisk --zap-all "${disk}" >/dev/null
  if [[ "${2:-}" == cifrado ]]; then
    sgdisk -n 1:0:+1G -t 1:ef00 -c 1:EFI -n 2:0:+1G -t 2:8300 -c 2:command-os-boot \
      -n 3:0:0 -t 3:8309 -c 3:command-os "${disk}" >/dev/null
    n=3
  else
    sgdisk -n 1:0:+1G -t 1:ef00 -c 1:EFI -n 2:0:0 -t 2:8304 -c 2:command-os "${disk}" >/dev/null
  fi
  partprobe "${disk}" 2>/dev/null || true
  udevadm settle 2>/dev/null || sleep 2
  local i
  for (( i = 1; i <= n; i++ )); do
    [[ -b "$(part_path "${disk}" "${i}")" ]] || die "no aparecieron las particiones nuevas de ${disk}"
  done
}

# --- Cifrado del disco (LUKS2; docs/instalacion.md § 4 y docs/decisiones.md) ---
# Se pregunta todo (cifrar, contraseña y clave de recuperación) antes de la confirmación del borrado:
# después ya no se pregunta nada. Las claves solo viven en variables de este proceso y se pasan a
# cryptsetup por la entrada estándar: nunca en argumentos, en el entorno ni en archivos.

LUKS_NAME=command-os   # /dev/mapper/command-os; el mismo en cryptdevice= (configure_system)
RECOVERY_DIGITS=48     # 8 grupos de 6 cifras, ~159 bits; solo cifras: se teclean en cualquier teclado

# ask_encryption — deja CIFRADO=si|no. Si ya viene en el entorno, no pregunta. Por defecto, sí.
ask_encryption() {
  local r
  case "${CIFRADO:-}" in si|no) return 0 ;; "") ;; *) die "CIFRADO debe ser si o no" ;; esac
  cat <<'EOF'

  Cifrado del disco (recomendado)
  Sin la contraseña nadie puede leer lo que hay en Command OS, aunque se lleve el equipo o saque
  el disco. Se escribe al encender, en la pantalla de arranque.

EOF
  while :; do
    read -rp "¿Cifrar el disco? [S/n]: " r || return 1
    case "${r,,}" in
      ""|s|si|sí) CIFRADO=si; return 0 ;;
      n|no) CIFRADO=no; return 0 ;;
    esac
  done
}

# password_problem CLAVE — por qué no vale como contraseña del disco (nada = vale). Sin tildes ni ñ:
# se teclea antes de que arranque el sistema y, si el teclado no las diera, no se podría entrar.
password_problem() {
  local LC_ALL=C   # byte a byte: una ñ o una tilde no entran en el rango ASCII de abajo
  if (( ${#1} < 8 )); then echo "tiene que tener al menos 8 caracteres"; return 0; fi
  if [[ ! "$1" =~ ^[\ -~]+$ ]]; then echo "solo letras sin tilde, cifras, espacios y símbolos (sin ñ ni tildes)"; fi
  return 0
}

# ask_disk_password — pide la contraseña dos veces hasta que valga y coincida; la deja en CLAVE_DISCO.
ask_disk_password() {
  local a b p
  echo "La contraseña del disco: al menos 8 caracteres, sin ñ ni tildes. No se muestra al escribirla."
  while :; do
    read -rsp "Contraseña del disco: " a || { echo; return 1; }
    echo
    p=$(password_problem "${a}")
    if [[ -n "${p}" ]]; then echo "No vale: ${p}."; continue; fi
    read -rsp "Repítela: " b || { echo; return 1; }
    echo
    if [[ "${a}" != "${b}" ]]; then echo "No coinciden. Otra vez."; continue; fi
    CLAVE_DISCO=${a}
    return 0
  done
}

# new_recovery_key — 48 cifras al azar (/dev/urandom: cada byte que es una cifra vale igual). Lee
# un bloque fijo y recorta en bash: `tr < /dev/urandom | head` acaba con SIGPIPE y, con pipefail,
# la función fallaría.
new_recovery_key() {
  local d=""
  while (( ${#d} < RECOVERY_DIGITS )); do
    d+=$(head -c 4096 /dev/urandom | LC_ALL=C tr -dc 0-9)
  done
  printf '%s' "${d:0:RECOVERY_DIGITS}"
}

# recovery_group CLAVE N — el grupo N (1–8) de 6 cifras.
recovery_group() { echo "${1:$(( ($2 - 1) * 6 )):6}"; }

# show_recovery_key — genera la clave de recuperación (CLAVE_RECUPERACION), la enseña y pide dos de
# sus grupos al azar para comprobar que se ha apuntado. Sin comprobarla no se sigue.
show_recovery_key() {
  local k g1 g2 a b i shown=""
  k=$(new_recovery_key)
  [[ ${#k} == "${RECOVERY_DIGITS}" ]] || die "no se pudo generar la clave de recuperación"
  for i in 1 2 3 4 5 6 7 8; do
    shown+="$(recovery_group "${k}" "${i}")"
    if (( i == 4 )); then shown+=$'\n      '; elif (( i < 8 )); then shown+="-"; fi
  done
  while :; do
    g1=$(( RANDOM % 4 + 1 )) g2=$(( RANDOM % 4 + 5 ))
    cat <<EOF

  Clave de recuperación
  Si olvidas la contraseña del disco, esta clave es la ÚNICA forma de entrar: Command OS no guarda
  ninguna copia y nadie puede recuperarla. Apúntala en papel (o en un gestor de contraseñas de otro
  aparato) y guárdala lejos del equipo. Se escribe al encender, en lugar de la contraseña.

      ${shown}

EOF
    read -rp "Para comprobarla, escribe el grupo ${g1}: " a || return 1
    read -rp "Y el grupo ${g2}: " b || return 1
    if [[ "${a}" == "$(recovery_group "${k}" "${g1}")" && "${b}" == "$(recovery_group "${k}" "${g2}")" ]]; then
      break
    fi
    echo "No coincide: revisa lo que has apuntado."
  done
  # Fuera de la pantalla y del historial de la terminal (sin depender de TERM, como clear).
  [[ -t 1 ]] && printf '\033[H\033[2J\033[3J'
  echo "Clave de recuperación comprobada."
  CLAVE_RECUPERACION=${k}
}

# prepare_encryption — pregunta si cifrar y, si sí, la contraseña y la clave de recuperación. La
# contraseña se escribe con la distribución de KB_LAYOUT, la misma que tendrá el splash al encender
# (keymap de /etc/vconsole.conf): si la consola en vivo tuviera otra, una contraseña con símbolos
# no se podría volver a escribir.
prepare_encryption() {
  ask_encryption || die "cancelado: no se ha tocado nada"
  [[ "${CIFRADO}" == si ]] || return 0
  if [[ -t 0 ]] && command -v loadkeys >/dev/null; then
    loadkeys "${KB_LAYOUT}" >/dev/null 2>&1 \
      || die "no se pudo poner el teclado ${KB_LAYOUT} (KB_LAYOUT) para escribir la contraseña"
  fi
  echo "Teclado: ${KB_LAYOUT} (el mismo con el que se escribirá la contraseña al encender)."
  ask_disk_password || die "cancelado: no se ha tocado nada"
  show_recovery_key || die "cancelado: no se ha tocado nada"
}

# luks_root PARTICIÓN — la cifra (LUKS2, argon2id) con CLAVE_DISCO y, en otra ranura, la clave de
# recuperación, y la abre como /dev/mapper/${LUKS_NAME}. allow-discards queda guardado en la
# cabecera (TRIM en los SSD; a cambio se ve qué zonas del disco están libres, no su contenido).
# Borra las claves de la memoria del proceso al terminar.
luks_root() {
  local part=$1
  [[ -n "${CLAVE_DISCO:-}" && -n "${CLAVE_RECUPERACION:-}" ]] || die "luks_root: faltan las claves"
  [[ ! -e "/dev/mapper/${LUKS_NAME}" ]] \
    || die "ya hay un volumen abierto como ${LUKS_NAME}: ciérralo (cryptsetup close ${LUKS_NAME}) y vuelve a empezar"
  printf '%s' "${CLAVE_DISCO}" | cryptsetup luksFormat --batch-mode --type luks2 --pbkdf argon2id \
    --label command-os --key-file=- "${part}" || die "no se pudo cifrar ${part}"
  printf '%s' "${CLAVE_DISCO}" | cryptsetup luksAddKey --batch-mode --pbkdf argon2id --key-file=- \
    "${part}" <(printf '%s' "${CLAVE_RECUPERACION}") || die "no se pudo añadir la clave de recuperación"
  printf '%s' "${CLAVE_DISCO}" | cryptsetup open --allow-discards --persistent --key-file=- \
    "${part}" "${LUKS_NAME}" || die "no se pudo abrir ${part}"
  LUKS_ABIERTO=1
  unset CLAVE_DISCO CLAVE_RECUPERACION
}

# close_luks — cierra /dev/mapper/${LUKS_NAME} si lo abrió luks_root (limpieza de los instaladores);
# uno que ya estuviera abierto no se toca.
close_luks() {
  if [[ -n "${LUKS_ABIERTO:-}" && -b "/dev/mapper/${LUKS_NAME}" ]]; then
    cryptsetup close "${LUKS_NAME}" && LUKS_ABIERTO=
  fi
  return 0
}

# luks_uuid_of MONTAJE — UUID del volumen LUKS sobre el que va MONTAJE (nada si no está cifrado).
luks_uuid_of() {
  local src dev
  src=$(findmnt -nvo SOURCE "$1") || return 0
  [[ "${src}" == /dev/mapper/* ]] || return 0
  dev=$(cryptsetup status "${src##*/}" 2>/dev/null | sed -nE 's/^ *device: *//p')
  [[ -n "${dev}" ]] && cryptsetup luksUUID "${dev}"
  return 0
}
