#!/usr/bin/env bash
# Command OS — instalador: convierte una instalación base de Arch (x86_64 o Arch Linux ARM) en
# Command OS. Idempotente: se puede volver a ejecutar en una máquina ya instalada.
#
# El sistema en sí (escritorio, marca, configuración de serie, ganchos de pacman) es el paquete
# command-os (os/pkg): aquí se construye desde este árbol y se instala, y las actualizaciones
# llegan después por pacman (command-os-update). Este script hace lo propio de cada máquina:
# repositorios, usuario e inicio automático, variante de hardware, servicios e instantáneas.
#
# Variables: COMMAND_OS_USER (deck), COMMAND_OS_VARIANT (os/variants/), COMMAND_OS_SSH=1 (servidor
# SSH encendido; de serie solo en la variante vbox).
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${COMMAND_OS_USER:-deck}"
TARGET_HOME="/home/${TARGET_USER}"
VARIANT="${COMMAND_OS_VARIANT:-}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Ejecutar como root (pacman, usuarios, servicios)." >&2
  exit 1
fi
# runuser conserva el entorno de root: HOME y XDG_CONFIG_HOME tienen que ser los del usuario.
as_user() {
  runuser -u "${TARGET_USER}" -- env -u XDG_CONFIG_HOME HOME="${TARGET_HOME}" USER="${TARGET_USER}" "$@"
}
# ¿Máquina virtual? Dentro de un chroot (imágenes construidas en WSL o desde el USB de Arch) no se
# sabe en qué hardware acabará el sistema: se trata como hardware real.
is_vm() { ! systemd-detect-virt --quiet --chroot && systemd-detect-virt --quiet --vm; }

echo "==> Repositorios (en x86_64, Arch de la fecha validada: os/pacman/snapshot-date)"
COMMAND_OS_PACMAN_DIR="${REPO_DIR}/pacman" bash "${REPO_DIR}/lib/apply-repos"
pacman -Syu --noconfirm
# Para construir el paquete: base-devel (makepkg) y git.
pacman -S --needed --noconfirm base-devel git

echo "==> Usuario: ${TARGET_USER}"
if ! id "${TARGET_USER}" &>/dev/null; then
  useradd -m -G wheel -s /bin/bash "${TARGET_USER}"
  echo "${TARGET_USER}:${TARGET_USER}" | chpasswd
  echo "==> Creado ${TARGET_USER} con contraseña '${TARGET_USER}': CAMBIARLA antes de entregar el equipo."
fi
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

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
    # Arrancar una instantánea de solo lectura necesita el gancho grub-btrfs-overlayfs, que solo
    # funciona en el initramfs clásico (udev), no en el de systemd. plymouth va después de udev.
    local hooks="HOOKS=(base udev plymouth autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck grub-btrfs-overlayfs)"
    if ! grep -qxF "${hooks}" /etc/mkinitcpio.conf; then
      sed -i -E "s/^HOOKS=.*/${hooks}/" /etc/mkinitcpio.conf
      mkinitcpio -P
    fi
  fi
}
if [[ "$(findmnt -no FSTYPE /)" == btrfs ]]; then
  echo "==> Instantáneas del sistema (btrfs + snapper)"
  setup_snapshots
else
  echo "==> Instantáneas: la raíz no es btrfs; sin instantáneas (solo en instalaciones nuevas)."
fi

echo "==> Paquete command-os (construido desde este árbol)"
BUILD=$(mktemp -d)
trap 'rm -rf "${BUILD}"' EXIT
cp -r "${REPO_DIR}" "${BUILD}/os"
chown -R "${TARGET_USER}:" "${BUILD}"
as_user bash -c "cd '${BUILD}/os/pkg' && makepkg -df --noconfirm >/dev/null"
PKG=$(ls "${BUILD}"/os/pkg/command-os-*.pkg.tar.*)
# --overwrite: rutas que el install.sh anterior al paquete copiaba a mano (máquinas ya instaladas).
pacman -U --noconfirm \
  --overwrite '/usr/share/command-os/*' --overwrite '/usr/share/themes/Command/*' \
  --overwrite '/usr/share/plymouth/themes/command/*' --overwrite '/usr/share/fonts/command-os/*' \
  --overwrite '/usr/share/pixmaps/command-os.png' --overwrite '/etc/xdg/fastfetch/*' \
  --overwrite '/etc/dconf/profile/user' --overwrite '/etc/dconf/db/local.d/00-command-os' \
  "${PKG}"

# Variante de hardware (p. ej. COMMAND_OS_VARIANT=pc-nvidia): paquetes extra de os/variants/.
if [[ -n "${VARIANT}" ]]; then
  VARIANT_PKGS="${REPO_DIR}/variants/${VARIANT}/packages.txt"
  [[ -f "${VARIANT_PKGS}" ]] || { echo "Variante desconocida: ${VARIANT}" >&2; exit 1; }
  echo "==> Variante: ${VARIANT}"
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

echo "==> Servicios"
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

echo "==> Cuenta de ${TARGET_USER}: configuración, inicio automático en tty1 y labwc"
as_user command-os-user-setup
# Ajustes de esta máquina (no son de serie): teclado y, en VM, el perfil ligero sin sombras.
LABWC_DIR="${TARGET_HOME}/.config/labwc"
as_user mkdir -p "${LABWC_DIR}/environment.d"
{
  echo '# Ajustes de esta máquina. Lo genera install.sh.'
  if [[ -s /etc/command-os/kb_layout ]]; then
    echo "XKB_DEFAULT_LAYOUT=$(tr -d '[:space:]' < /etc/command-os/kb_layout)"
  fi
} > "${LABWC_DIR}/environment.d/local.env"
if is_vm; then
  # Render por software: sin halo ni sombras (cada fotograma cuenta). El producto conserva el tema.
  printf '%s\n' '# Perfil ligero para VM (render por software). Lo genera install.sh.' \
    'window.active.shadow.size: 0' 'window.inactive.shadow.size: 0' > "${LABWC_DIR}/themerc-override"
fi
chown -R "${TARGET_USER}:" "${LABWC_DIR}"

mkdir -p /etc/systemd/system/getty@tty1.service.d
# Sin texto en pantalla: ni /etc/issue, ni prompt, ni "login:"; .hushlogin quita motd y último acceso.
cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ${TARGET_USER} --noclear --skip-login --nonewline --noissue --nohints %I \$TERM
TTYVTDisallocate=no
EOF

BASH_PROFILE="${TARGET_HOME}/.bash_profile"
touch "${BASH_PROFILE}"
MARKER="# --- Command OS: autostart labwc on tty1 ---"
# Se reemplaza el bloque entero (hasta el `fi` de nivel 0) para recoger cambios al re-ejecutar.
sed -i "\|${MARKER}|,/^fi\$/d" "${BASH_PROFILE}"
cat >> "${BASH_PROFILE}" <<'EOF'
# --- Command OS: autostart labwc on tty1 ---
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  # GPU virtual (VirtualBox, QEMU sin 3D): wlroots necesita permiso para el render por software
  # y cursor por software. En hardware real (Raspberry Pi 5, PC) no se tocan.
  if systemd-detect-virt --quiet; then
    export WLR_NO_HARDWARE_CURSORS=1
    export WLR_RENDERER_ALLOW_SOFTWARE=1
  fi
  # --merge-config: la configuración de serie (/etc/xdg/labwc) más lo que el usuario añada en
  # ~/.config/labwc. El log va a un archivo y no a tty1 (sin texto entre el splash y el escritorio).
  exec labwc --merge-config > "${XDG_RUNTIME_DIR:-/tmp}/labwc.log" 2>&1
fi
EOF
chown "${TARGET_USER}:" "${BASH_PROFILE}"

echo "==> Command OS instalado ($(cat /usr/share/command-os/version))."
