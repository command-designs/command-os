#!/usr/bin/env bash
# Command OS — instalador: convierte una instalación base de Arch (x86_64 o Arch Linux ARM) en
# Command OS. Idempotente: se puede volver a ejecutar en una máquina ya instalada.
#
# El sistema en sí (escritorio, marca, configuración de serie, ganchos de pacman) es el paquete
# command-os (os/pkg): aquí se construye desde este árbol y se instala, y las actualizaciones
# llegan después por pacman (command-os-update). Este script hace lo propio de cada máquina:
# repositorios, variante de hardware, servicios e instantáneas.
#
# No crea ninguna cuenta: al encender por primera vez, el asistente de primer arranque pide la de
# quien va a usar el equipo (lib/apply-login, docs/cuentas.md).
#
# Variables: COMMAND_OS_VARIANT (os/variants/), COMMAND_OS_SSH=1 (servidor SSH encendido; de serie
# solo en la variante vbox), COMMAND_OS_PAQUETE=repo (instala el paquete firmado del repositorio en
# vez de construirlo: lo pone el instalador publicado), COMMAND_OS_DEV_USER=deck (solo imágenes de
# desarrollo: crea esa cuenta con su nombre como contraseña y entra sola, sin asistente; nunca en un
# equipo que se entrega).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEV_USER="${COMMAND_OS_DEV_USER:-}"
VARIANT="${COMMAND_OS_VARIANT:-}"
# Mensajes (docs/idioma.md). Desde el instalador del PC (build/x86/lib.sh: configure_system), el
# catálogo que compiló para su idioma: el paquete aún no está instalado.
source "${REPO_DIR}/lib/textos.sh"
[[ -n "${COMMAND_OS_LOCALE_DIR:-}" ]] && export TEXTDOMAINDIR=${COMMAND_OS_LOCALE_DIR}

if [[ "$(id -u)" -ne 0 ]]; then
  echo "$(t 'Ejecutar como root (pacman, usuarios, servicios).')" >&2
  exit 1
fi
# runuser conserva el entorno de root: HOME y XDG_CONFIG_HOME tienen que ser los del usuario.
as_user() {
  local u=$1; shift
  runuser -u "${u}" -- env -u XDG_CONFIG_HOME HOME="$(getent passwd "${u}" | cut -d: -f6)" USER="${u}" "$@"
}
# ¿La raíz va sobre un volumen cifrado (LUKS)? lsblk -s recorre de / hacia el disco.
root_is_encrypted() { lsblk -nso TYPE "$(findmnt -nvo SOURCE /)" 2>/dev/null | grep -qx crypt; }
# ¿Máquina virtual? Dentro de un chroot (imágenes construidas en WSL o desde el USB de Arch) no se
# sabe en qué hardware acabará el sistema: se trata como hardware real.
is_vm() { ! systemd-detect-virt --quiet --chroot && systemd-detect-virt --quiet --vm; }

echo "==> $(t 'Repositorios (en x86_64, Arch de la fecha validada: os/pacman/snapshot-date)')"
COMMAND_OS_PACMAN_DIR="${REPO_DIR}/pacman" bash "${REPO_DIR}/lib/apply-repos"
pacman -Syu --noconfirm
# Para construir el paquete: base-devel (makepkg) y git.
pacman -S --needed --noconfirm base-devel git

# Cuenta de desarrollo (VM de pruebas): se crea antes del paquete para que apply-login la tome como
# la cuenta principal con inicio automático y no aparezca el asistente.
if [[ -n "${DEV_USER}" ]]; then
  echo "==> $(t 'Cuenta de desarrollo: %s (contraseña «%s»; solo para pruebas)' "${DEV_USER}" "${DEV_USER}")"
  if ! id "${DEV_USER}" &>/dev/null; then
    useradd -m -G wheel -s /bin/bash "${DEV_USER}"
    echo "${DEV_USER}:${DEV_USER}" | chpasswd
  fi
  install -d /etc/command-os /var/lib/command-os
  echo "${DEV_USER}" > /etc/command-os/cuenta-principal
  echo "${DEV_USER}" > /etc/command-os/inicio-automatico
  touch /var/lib/command-os/configurado
fi
# Variantes de dispositivo (p. ej. el cyberdeck): el asistente propone entrar sin contraseña.
if [[ -n "${VARIANT}" && -e "${REPO_DIR}/variants/${VARIANT}/inicio-automatico-de-serie" ]]; then
  install -d /etc/command-os
  touch /etc/command-os/inicio-automatico-de-serie
fi

# --overwrite: rutas que el install.sh anterior al paquete copiaba a mano (máquinas ya instaladas).
OVERWRITE=(
  --overwrite '/usr/share/command-os/*' --overwrite '/usr/share/themes/Command/*'
  --overwrite '/usr/share/plymouth/themes/command/*' --overwrite '/usr/share/fonts/command-os/*'
  --overwrite '/usr/share/pixmaps/command-os.png' --overwrite '/etc/xdg/fastfetch/*'
  --overwrite '/etc/dconf/profile/user' --overwrite '/etc/dconf/db/local.d/00-command-os'
)
if [[ "${COMMAND_OS_PAQUETE:-}" == repo ]]; then
  # Instalador publicado (build/x86/instalar-command-os.sh): el paquete firmado del repositorio, el
  # mismo del que se actualizará el equipo. pacman comprueba la firma (SigLevel = Required).
  echo "==> $(t 'Paquete command-os (del repositorio firmado)')"
  grep -q '^\[command-os\]$' /etc/pacman.conf \
    || { echo "$(t 'No se pudo configurar el repositorio de Command OS (¿sin internet?).')" >&2; exit 1; }
  pacman -S --noconfirm "${OVERWRITE[@]}" command-os   # bases de datos ya al día (-Syu de arriba)
else
  echo "==> $(t 'Paquete command-os (construido desde este árbol)')"
  BUILD=$(mktemp -d)
  trap 'rm -rf "${BUILD}"; userdel command-os-build 2>/dev/null || true' EXIT
  cp -r "${REPO_DIR}" "${BUILD}/os"
  # makepkg no se ejecuta como root: una cuenta de sistema temporal, que se borra al terminar.
  id command-os-build &>/dev/null || useradd -r -M -d "${BUILD}" -s /usr/bin/nologin command-os-build
  chown -R command-os-build: "${BUILD}"
  as_user command-os-build bash -c "cd '${BUILD}/os/pkg' && makepkg -df --noconfirm >/dev/null"
  PKG=$(ls "${BUILD}"/os/pkg/command-os-*.pkg.tar.*)
  pacman -U --noconfirm "${OVERWRITE[@]}" "${PKG}"
fi

# --- Instantáneas (raíz en btrfs: lo que crean build/x86/build-image.sh y install-dualboot.sh) ---
# snapper guarda el estado del sistema y snap-pac hace una instantánea antes y otra después de cada
# operación de pacman. Con GRUB, grub-btrfs las añade al menú de arranque (Esc al encender) y el
# gancho de overlayfs permite arrancar una de solo lectura como si fuera un sistema en vivo; desde
# ahí, command-os-rollback la deja como sistema. /home no entra: los archivos del usuario no
# retroceden.
setup_snapshots() {
  pacman -S --needed --noconfirm btrfs-progs snapper snap-pac
  if [[ ! -f /etc/snapper/configs/root ]]; then
    if mountpoint -q /.snapshots; then
      # Los instaladores montan el subvolumen @snapshots en /.snapshots; snapper quiere crear el
      # suyo: se le deja y se cambia por @snapshots (así las instantáneas no viven dentro de @).
      umount /.snapshots
      rmdir /.snapshots
      snapper --no-dbus -c root create-config /
      btrfs subvolume delete /.snapshots >/dev/null
      mkdir /.snapshots
      mount /.snapshots
    else
      snapper --no-dbus -c root create-config /
    fi
    chmod 750 /.snapshots
  fi
  # Pocas instantáneas y solo las de pacman: protegen las actualizaciones sin llenar el disco.
  snapper --no-dbus -c root set-config NUMBER_LIMIT=10 NUMBER_LIMIT_IMPORTANT=5 \
    NUMBER_MIN_AGE=0 TIMELINE_CREATE=no TIMELINE_CLEANUP=no
  systemctl enable snapper-cleanup.timer

  if [[ -f /etc/default/grub ]]; then
    pacman -S --needed --noconfirm grub-btrfs inotify-tools
    systemctl enable grub-btrfsd.service
    # Nombre de la entrada del menú de GRUB (Esc al encender).
    if [[ -f /etc/default/grub-btrfs/config ]]; then
      sed -i -E 's|^#?GRUB_BTRFS_SUBMENUNAME=.*|GRUB_BTRFS_SUBMENUNAME="Command OS: instantáneas (volver atrás)"|' \
        /etc/default/grub-btrfs/config
    fi
    # Arrancar una instantánea de solo lectura necesita el gancho grub-btrfs-overlayfs, que solo
    # funciona en el initramfs clásico (udev), no en el de systemd. plymouth va después de udev
    # (por eso esto va después de instalar el paquete, que trae plymouth).
    local hooks="HOOKS=(base udev plymouth autodetect microcode modconf kms keyboard keymap block filesystems fsck grub-btrfs-overlayfs)"
    # Raíz cifrada (build/x86/lib.sh: luks_root): la contraseña se pide en el splash
    # (command-os-cifrado, del paquete) antes de encrypt, que solo aporta cryptsetup y los módulos.
    # keyboard va antes de autodetect: así entran todos los teclados, no solo el que había al
    # instalar (uno USB enchufado después tiene que poder escribir la contraseña), y keymap pone la
    # distribución de /etc/vconsole.conf.
    if root_is_encrypted; then
      hooks="HOOKS=(base udev plymouth keyboard autodetect microcode modconf kms keymap block command-os-cifrado encrypt filesystems fsck grub-btrfs-overlayfs)"
    fi
    if ! grep -qxF "${hooks}" /etc/mkinitcpio.conf; then
      sed -i -E "s/^HOOKS=.*/${hooks}/" /etc/mkinitcpio.conf
      mkinitcpio -P
    fi
  fi
}
if [[ "$(findmnt -no FSTYPE /)" == btrfs ]]; then
  echo "==> $(t 'Instantáneas del sistema (btrfs + snapper)')"
  setup_snapshots
else
  echo "==> $(t 'Instantáneas: la raíz no es btrfs; sin instantáneas (solo en instalaciones nuevas).')"
fi

# Variante de hardware (p. ej. COMMAND_OS_VARIANT=pc-nvidia): paquetes extra de os/variants/.
if [[ -n "${VARIANT}" ]]; then
  VARIANT_PKGS="${REPO_DIR}/variants/${VARIANT}/packages.txt"
  [[ -f "${VARIANT_PKGS}" ]] || { echo "$(t 'Variante desconocida: %s' "${VARIANT}")" >&2; exit 1; }
  echo "==> $(t 'Variante: %s' "${VARIANT}")"
  mapfile -t VARIANT_PACKAGES < <(grep -vE '^\s*(#|$)' "${VARIANT_PKGS}")
  pacman -S --needed --noconfirm "${VARIANT_PACKAGES[@]}"
  if [[ "${VARIANT}" == "vbox" ]]; then
    systemctl enable vboxservice.service
  fi
  if [[ "${VARIANT}" == "pc-nvidia" ]]; then
    # Solo si hay GPU NVIDIA real: en una VM (virtio-gpu) esto rompería el renderizado.
    cat > /etc/profile.d/command-os-nvidia.sh <<'EOF'
if [ -e /proc/driver/nvidia/version ]; then
  export GBM_BACKEND=nvidia-drm
  export __GLX_VENDOR_LIBRARY_NAME=nvidia
  export WLR_NO_HARDWARE_CURSORS=1
fi
EOF
  fi
fi

echo "==> $(t 'Servicios')"
systemctl enable seatd.service NetworkManager.service
# Acceso remoto: apagado en el producto (un aparato de cliente no debe exponer SSH). Solo en la VM
# de pruebas (variante vbox) o si se pide con COMMAND_OS_SSH=1 (imágenes de desarrollo).
if [[ "${VARIANT}" == "vbox" || "${COMMAND_OS_SSH:-0}" == "1" ]]; then
  systemctl enable sshd.service
else
  systemctl disable sshd.service 2>/dev/null || true
fi
# Audio: PipeWire por socket para todos los usuarios (sesión gráfica incluida).
systemctl --global enable pipewire.socket pipewire-pulse.socket wireplumber.service

echo "==> $(t 'Entrada al equipo: greetd (asistente de primer arranque, inicio de sesión o inicio automático)')"
/usr/lib/command-os/apply-login
if [[ -n "${DEV_USER}" ]]; then
  as_user "${DEV_USER}" command-os-user-setup
fi

echo "==> $(t 'Command OS instalado (%s).' "$(cat /usr/share/command-os/version)")"
