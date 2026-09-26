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
for dir in hypr waybar alacritty wofi kitty; do
  src="${REPO_DIR}/dotfiles/${dir}"
  [[ -d "${src}" ]] || continue
  rm -rf "${TARGET_HOME}/.config/${dir}"
  cp -r "${src}" "${TARGET_HOME}/.config/${dir}"
done
chown -R "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.config"

echo "==> Enabling core services"
systemctl enable seatd.service
systemctl enable NetworkManager.service
systemctl enable sshd.service

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
  exec Hyprland
fi
EOF
fi
chown "${TARGET_USER}:${TARGET_USER}" "${BASH_PROFILE}"

echo "==> Command OS layer installed."
