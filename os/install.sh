#!/usr/bin/env bash
# Command OS installer — the curated layer on top of a base Arch Linux system.
# Idempotent: safe to re-run on an already-provisioned machine to pick up
# package-list or dotfiles changes without reinstalling the base OS.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_USER="${COMMAND_OS_USER:-deck}"
TARGET_HOME="/home/${TARGET_USER}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Run as root (needed for pacman + chown)." >&2
  exit 1
fi

echo "==> Updating package databases"
pacman -Sy --noconfirm

echo "==> Installing package layer from packages.txt"
mapfile -t PACKAGES < <(grep -vE '^\s*(#|$)' "${REPO_DIR}/packages.txt")
pacman -S --needed --noconfirm "${PACKAGES[@]}"

# Variante opcional (ej. COMMAND_OS_VARIANT=pc-nvidia para PC x86_64 con GPU
# NVIDIA): paquetes extra en os/variants/<variante>/packages.txt.
VARIANT="${COMMAND_OS_VARIANT:-}"
if [[ -n "${VARIANT}" ]]; then
  VARIANT_PKGS="${REPO_DIR}/variants/${VARIANT}/packages.txt"
  [[ -f "${VARIANT_PKGS}" ]] || { echo "Variante desconocida: ${VARIANT}" >&2; exit 1; }
  echo "==> Installing variant packages: ${VARIANT}"
  mapfile -t VARIANT_PACKAGES < <(grep -vE '^\s*(#|$)' "${VARIANT_PKGS}")
  pacman -S --needed --noconfirm "${VARIANT_PACKAGES[@]}"
  if [[ "${VARIANT}" == "vbox" ]]; then
    systemctl enable vboxservice.service
  fi
  if [[ "${VARIANT}" == "pc-nvidia" ]]; then
    # Solo se exporta si hay GPU NVIDIA real: en una VM (virtio-gpu) esto
    # rompería el renderizado.
    cat > /etc/profile.d/command-os-nvidia.sh <<'EOF'
if [ -e /proc/driver/nvidia/version ]; then
  export GBM_BACKEND=nvidia-drm
  export __GLX_VENDOR_LIBRARY_NAME=nvidia
  export WLR_NO_HARDWARE_CURSORS=1
fi
EOF
  fi
fi

echo "==> Installing Command OS branding (logo, wallpaper, fonts)"
BRANDING="${REPO_DIR}/branding"
install -d /usr/share/command-os/logo /usr/share/command-os/wallpapers /usr/share/fonts/command-os
install -m 644 "${BRANDING}"/logo/* /usr/share/command-os/logo/
install -m 644 "${BRANDING}"/wallpapers/* /usr/share/command-os/wallpapers/
# Oxanium y Geist (BRAND.md § 5) no están en los repos de Arch: se empaquetan aquí (OFL).
install -m 644 "${BRANDING}"/fonts/*.ttf /usr/share/fonts/command-os/
fc-cache -f /usr/share/fonts/command-os

echo "==> Installing system sounds and helper"
install -d /usr/share/command-os/sounds
install -m 644 "${BRANDING}"/sounds/*.wav /usr/share/command-os/sounds/
install -m 755 "${REPO_DIR}/bin/command-os-sound" /usr/local/bin/command-os-sound

echo "==> Setting system identity (os-release, issue, motd)"
# /etc/os-release es un symlink a /usr/lib/os-release: se reemplaza por un archivo propio.
rm -f /etc/os-release
install -m 644 "${BRANDING}/os-release" /etc/os-release
install -m 644 "${BRANDING}/issue" /etc/issue
install -m 644 "${BRANDING}/motd" /etc/motd

echo "==> Installing Plymouth boot splash"
rm -rf /usr/share/plymouth/themes/command
install -d /usr/share/plymouth/themes/command
install -m 644 "${BRANDING}"/plymouth/command/* /usr/share/plymouth/themes/command/
install -d /etc/plymouth
printf '[Daemon]\nTheme=command\nShowDelay=0\n' > /etc/plymouth/plymouthd.conf
if [[ -f /etc/mkinitcpio.conf ]] && ! grep -qE '^HOOKS=.*plymouth' /etc/mkinitcpio.conf; then
  # plymouth va justo después de systemd (initramfs systemd) o de udev (initramfs busybox).
  if grep -qE '^HOOKS=.*\bsystemd\b' /etc/mkinitcpio.conf; then
    sed -i -E '/^HOOKS=/ s/\bsystemd\b/systemd plymouth/' /etc/mkinitcpio.conf
  else
    sed -i -E '/^HOOKS=/ s/\budev\b/udev plymouth/' /etc/mkinitcpio.conf
  fi
fi
if command -v mkinitcpio >/dev/null; then mkinitcpio -P; fi

echo "==> Branding GRUB"
if [[ -f /etc/default/grub ]]; then
  set_grub() {  # set_grub CLAVE 'valor' — reemplaza o añade, idempotente
    if grep -qE "^#?${1}=" /etc/default/grub; then
      sed -i -E "s|^#?${1}=.*|${1}=${2}|" /etc/default/grub
    else
      echo "${1}=${2}" >> /etc/default/grub
    fi
  }
  set_grub GRUB_DISTRIBUTOR '"Command OS"'
  set_grub GRUB_TIMEOUT 2
  set_grub GRUB_TERMINAL_OUTPUT gfxterm
  set_grub GRUB_GFXMODE auto
  set_grub GRUB_BACKGROUND '"/usr/share/command-os/wallpapers/command-void.png"'
  set_grub GRUB_COLOR_NORMAL '"light-gray/black"'
  set_grub GRUB_COLOR_HIGHLIGHT '"white/black"'
  if ! grep -qE '^GRUB_CMDLINE_LINUX_DEFAULT=.*splash' /etc/default/grub; then
    sed -i -E 's/^(GRUB_CMDLINE_LINUX_DEFAULT=")(.*)"/\1\2 quiet splash"/' /etc/default/grub
  fi
fi

echo "==> Ensuring target user exists: ${TARGET_USER}"
if ! id "${TARGET_USER}" &>/dev/null; then
  useradd -m -G wheel -s /bin/bash "${TARGET_USER}"
  echo "${TARGET_USER}:${TARGET_USER}" | chpasswd
  echo "==> Created ${TARGET_USER} with default password '${TARGET_USER}' — CHANGE THIS before shipping."
fi

echo "==> Enabling wheel sudo access"
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo "==> Deploying dotfiles to ${TARGET_HOME}"
mkdir -p "${TARGET_HOME}/.config"
for dir in hypr waybar alacritty wofi kitty mako nano; do
  src="${REPO_DIR}/dotfiles/${dir}"
  [[ -d "${src}" ]] || continue
  # Con la sesión abierta, Hyprland escribe en su carpeta y `rm -rf` puede fallar:
  # se limpia sin abortar y se copia encima.
  rm -rf "${TARGET_HOME}/.config/${dir}" 2>/dev/null || true
  mkdir -p "${TARGET_HOME}/.config/${dir}"
  cp -rT "${src}" "${TARGET_HOME}/.config/${dir}"
done
# Ajustes locales de Hyprland (se carga con `source` al final de hyprland.conf).
# En VM el render es por software y el hardware no da para el movimiento completo:
# se acorta la duración de las animaciones (sin tocar el perfil del producto).
if systemd-detect-virt --quiet; then
  cat > "${TARGET_HOME}/.config/hypr/local.conf" <<'LOCAL'
# Perfil ligero para VM (render por software).
decoration {
    dim_inactive = false
}
animation = workspacesIn, 1, 3, out, slide
animation = workspacesOut, 1, 2, emphasized, slide
animation = border, 0
LOCAL
else
  : > "${TARGET_HOME}/.config/hypr/local.conf"
fi

echo "==> Configuring developer shell (bashrc, nano)"
mkdir -p "${TARGET_HOME}/.config/command-os"
install -m 644 "${REPO_DIR}/dotfiles/bash/command-os.bashrc" "${TARGET_HOME}/.config/command-os/bashrc"
BASHRC="${TARGET_HOME}/.bashrc"
touch "${BASHRC}"
RC_MARKER="# --- Command OS: shell de desarrollo ---"
# Se reemplaza el bloque entero para recoger cambios al re-ejecutar.
sed -i "\|${RC_MARKER}|,\|# --- fin Command OS ---|d" "${BASHRC}"
printf '%s\n[ -r ~/.config/command-os/bashrc ] && . ~/.config/command-os/bashrc\n# --- fin Command OS ---\n' "${RC_MARKER}" >> "${BASHRC}"
chown -R "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.config" "${BASHRC}"

echo "==> Enabling core services"
systemctl enable seatd.service
systemctl enable NetworkManager.service
systemctl enable sshd.service
# Audio: PipeWire por socket para todos los usuarios (sesión de Hyprland incluida).
systemctl --global enable pipewire.socket pipewire-pulse.socket wireplumber.service

echo "==> Configuring tty1 autologin + auto-start Hyprland for ${TARGET_USER}"
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ${TARGET_USER} --noclear %I \$TERM
EOF

BASH_PROFILE="${TARGET_HOME}/.bash_profile"
touch "${BASH_PROFILE}"
MARKER="# --- Command OS: autostart Hyprland on tty1 ---"
# Se reemplaza el bloque entero (hasta el `fi` de nivel 0) para recoger cambios al re-ejecutar.
sed -i "\|${MARKER}|,/^fi\$/d" "${BASH_PROFILE}"
if ! grep -qF "${MARKER}" "${BASH_PROFILE}"; then
  cat >> "${BASH_PROFILE}" <<'EOF'
# --- Command OS: autostart Hyprland on tty1 ---
if [ -z "$WAYLAND_DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  # Virtualized GPUs (e.g. VirtualBox's vmwgfx) don't support real hardware
  # cursors/GBM the way Hyprland expects; force the software fallback there.
  # Real hardware (Raspberry Pi 5) hits neither of these and runs natively.
  if systemd-detect-virt --quiet; then
    export WLR_NO_HARDWARE_CURSORS=1
    export WLR_RENDERER_ALLOW_SOFTWARE=1
  fi
  # Hyprland >= 0.55 pide arrancar con start-hyprland (watchdog + entorno de sesión).
  if command -v start-hyprland >/dev/null; then exec start-hyprland; fi
  exec Hyprland
fi
EOF
fi
chown "${TARGET_USER}:${TARGET_USER}" "${BASH_PROFILE}"

echo "==> Command OS layer installed."
