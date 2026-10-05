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

echo "==> Installing system sounds and helpers (sonido, energía, volumen, atajos)"
install -d /usr/share/command-os/sounds
install -m 644 "${BRANDING}"/sounds/*.wav /usr/share/command-os/sounds/
for helper in command-os-sound command-os-power command-os-volume command-os-keys command-os-desktops; do
  install -m 755 "${REPO_DIR}/bin/${helper}" "/usr/local/bin/${helper}"
done

echo "==> Installing labwc window theme (Command)"
# Marco, barra de título, menús y Alt+Tab. Los botones SVG salen de build/make-labwc-buttons.py.
rm -rf /usr/share/themes/Command
install -d /usr/share/themes/Command/labwc
install -m 644 "${BRANDING}"/labwc/Command/labwc/* /usr/share/themes/Command/labwc/

echo "==> Theming GTK/Qt apps (adw-gtk3 recoloreado, Papirus, modo oscuro)"
# Los colores van en ~/.config/gtk-{3,4}.0 (dotfiles); aquí, lo que es de sistema: carpetas de
# Papirus en el color de Command OS (con hook de pacman, el paquete las devuelve al azul) y
# valores por defecto de dconf para todos los usuarios (modo oscuro para Firefox, portales, GTK 4).
install -m 755 "${REPO_DIR}/bin/command-os-icon-folders" /usr/local/bin/command-os-icon-folders
/usr/local/bin/command-os-icon-folders grey
install -d /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/command-os-icon-folders.hook <<'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = papirus-icon-theme

[Action]
Description = Command OS: color de las carpetas de Papirus
When = PostTransaction
Exec = /usr/local/bin/command-os-icon-folders grey
EOF
install -d /etc/dconf/profile /etc/dconf/db/local.d
printf 'user-db:user\nsystem-db:local\n' > /etc/dconf/profile/user
cat > /etc/dconf/db/local.d/00-command-os <<'EOF'
[org/gnome/desktop/interface]
color-scheme='prefer-dark'
gtk-theme='adw-gtk3-dark'
icon-theme='Papirus-Dark'
cursor-theme='Adwaita'
cursor-size=24
accent-color='red'
font-name='Geist 10'
document-font-name='Geist 10'
monospace-font-name='JetBrainsMono Nerd Font 10'

[org/gnome/desktop/wm/preferences]
button-layout=':minimize,maximize,close'
EOF
dconf update

echo "==> Setting system identity (os-release, issue, motd, logo, fastfetch)"
# /etc/os-release es un symlink a /usr/lib/os-release: se reemplaza por un archivo propio.
rm -f /etc/os-release
install -m 644 "${BRANDING}/os-release" /etc/os-release
# LOGO=command-os de os-release: el icono que buscan las apps que enseñan el logo del sistema.
install -Dm 644 "${BRANDING}/logo/command-mark-white.png" /usr/share/pixmaps/command-os.png
# fastfetch con el logo de la C y la paleta de la marca, para todos los usuarios (/etc/xdg).
install -d /usr/share/command-os/fastfetch /etc/xdg/fastfetch
install -m 644 "${BRANDING}/fastfetch/command-logo.txt" /usr/share/command-os/fastfetch/
install -m 644 "${BRANDING}/fastfetch/config.jsonc" /etc/xdg/fastfetch/config.jsonc
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

echo "==> Silent boot (x86: GRUB · Raspberry Pi: cmdline.txt/config.txt)"
# Producto para clientes: del encendido al escritorio solo se ve el splash, sin texto del
# cargador, del kernel ni de systemd. Soporte técnico: Esc en GRUB muestra el menú y Esc en el
# splash muestra el arranque detallado.
SILENT_ARGS="quiet splash loglevel=3 rd.udev.log_level=3 systemd.show_status=auto rd.systemd.show_status=auto vt.global_cursor_default=0"
add_args() {  # add_args "línea actual" -> añade los SILENT_ARGS que falten
  local line="$1" arg
  for arg in ${SILENT_ARGS}; do
    [[ " ${line} " == *" ${arg} "* ]] || line="${line:+${line} }${arg}"
  done
  printf '%s' "${line}"
}

if [[ -f /etc/default/grub ]]; then
  set_grub() {  # set_grub CLAVE 'valor' — reemplaza o añade, idempotente
    if grep -qE "^#?${1}=" /etc/default/grub; then
      sed -i -E "s|^#?${1}=.*|${1}=${2}|" /etc/default/grub
    else
      echo "${1}=${2}" >> /etc/default/grub
    fi
  }
  set_grub GRUB_DISTRIBUTOR '"Command OS"'
  if [[ -f /etc/command-os/dualboot ]]; then
    # Dual boot con Windows (build/x86/install-dualboot.sh): menú visible para elegir. La
    # entrada de Windows la pone /etc/grub.d/35_command-os-windows.
    set_grub GRUB_TIMEOUT 5
    set_grub GRUB_TIMEOUT_STYLE menu
  else
    # Menú oculto: espera 1 s en silencio; Esc lo muestra (recuperación).
    set_grub GRUB_TIMEOUT 1
    set_grub GRUB_TIMEOUT_STYLE hidden
  fi
  set_grub GRUB_TERMINAL_OUTPUT gfxterm
  set_grub GRUB_GFXMODE auto
  set_grub GRUB_GFXPAYLOAD_LINUX keep
  # VirtualBox: todo el arranque a 1280x720 (el driver vboxvideo pondría 1024x768). Con render por
  # software, 1080p no pasa de ~5 FPS y 720p es el mejor equilibrio; labwc reutiliza ese modo
  # (<reuseOutputMode>), así que no hay cambio de resolución ni pantallazo negro al entrar.
  if [[ "$(systemd-detect-virt)" == "oracle" ]]; then
    SILENT_ARGS="${SILENT_ARGS} video=1280x720"
  fi
  set_grub GRUB_BACKGROUND '"/usr/share/command-os/wallpapers/command-void.png"'
  set_grub GRUB_COLOR_NORMAL '"light-gray/black"'
  set_grub GRUB_COLOR_HIGHLIGHT '"light-red/black"'
  current=$(sed -nE 's/^GRUB_CMDLINE_LINUX_DEFAULT="(.*)"/\1/p' /etc/default/grub)
  set_grub GRUB_CMDLINE_LINUX_DEFAULT "\"$(add_args "${current}")\""
  # Sin "Loading Linux ..." / "Loading initial ramdisk ...". Una actualización del paquete grub
  # restaura 10_linux: install.sh lo vuelve a quitar al re-ejecutarse.
  [[ -f /etc/grub.d/10_linux ]] && sed -i '/echo.*"\$message"/d' /etc/grub.d/10_linux
  if [[ -f /boot/grub/grub.cfg ]] && command -v grub-mkconfig >/dev/null; then
    grub-mkconfig -o /boot/grub/grub.cfg
  fi
fi

if [[ -f /boot/cmdline.txt ]]; then
  # Raspberry Pi: el kernel escribe en tty3 en vez de en la pantalla (consola serie intacta).
  line=$(tr '\n' ' ' < /boot/cmdline.txt | sed -E 's/\bconsole=tty1\b/console=tty3/; s/ +/ /g; s/ $//')
  printf '%s\n' "$(add_args "${line}")" > /boot/cmdline.txt
fi
if [[ -f /boot/config.txt ]]; then
  # Sin el cuadro arcoíris del firmware al encender.
  grep -qE '^disable_splash=' /boot/config.txt \
    && sed -i -E 's/^disable_splash=.*/disable_splash=1/' /boot/config.txt \
    || echo 'disable_splash=1' >> /boot/config.txt
fi

# El splash se queda en pantalla hasta que labwc toma el control (sin parpadeo de consola). labwc
# reutiliza además el modo de pantalla del splash (<reuseOutputMode> en rc.xml): sin modeset.
install -d /etc/systemd/system/plymouth-quit.service.d
cat > /etc/systemd/system/plymouth-quit.service.d/retain-splash.conf <<'EOF'
[Service]
ExecStart=
ExecStart=-/usr/bin/plymouth quit --retain-splash
EOF

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
for dir in labwc hypr waybar alacritty wofi kitty mako nano gtk-3.0 gtk-4.0 xdg-desktop-portal; do
  src="${REPO_DIR}/dotfiles/${dir}"
  [[ -d "${src}" ]] || continue
  # Con la sesión abierta, algún programa puede estar escribiendo en su carpeta y `rm -rf`
  # fallar: se limpia sin abortar y se copia encima. Las de GTK no se borran: guardan datos del
  # usuario (marcadores de Thunar en gtk-3.0/bookmarks).
  [[ "${dir}" == gtk-* ]] || rm -rf "${TARGET_HOME}/.config/${dir}" 2>/dev/null || true
  mkdir -p "${TARGET_HOME}/.config/${dir}"
  cp -rT "${src}" "${TARGET_HOME}/.config/${dir}"
done
chmod 755 "${TARGET_HOME}/.config/labwc/autostart"

# Ajustes de esta máquina, fuera de los dotfiles del producto (labwc-config(5)):
# environment.d/local.env (se lee después de environment) y themerc-override.
LABWC_DIR="${TARGET_HOME}/.config/labwc"
mkdir -p "${LABWC_DIR}/environment.d"
LOCAL_ENV="${LABWC_DIR}/environment.d/local.env"
echo '# Ajustes de esta máquina. Lo genera install.sh.' > "${LOCAL_ENV}"
# Distribución de teclado de esta máquina (ej. "es"), si se fijó al instalar.
if [[ -s /etc/command-os/kb_layout ]]; then
  echo "XKB_DEFAULT_LAYOUT=$(tr -d '[:space:]' < /etc/command-os/kb_layout)" >> "${LOCAL_ENV}"
fi
if systemd-detect-virt --quiet; then
  # En VM el render es por software: sin halo ni sombras (cada fotograma cuenta). El producto
  # conserva el tema completo.
  cat > "${LABWC_DIR}/themerc-override" <<'EOF'
# Perfil ligero para VM (render por software). Lo genera install.sh.
window.active.shadow.size: 0
window.inactive.shadow.size: 0
EOF
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
# Audio: PipeWire por socket para todos los usuarios (sesión gráfica incluida).
systemctl --global enable pipewire.socket pipewire-pulse.socket wireplumber.service

echo "==> Configuring tty1 autologin + auto-start labwc for ${TARGET_USER}"
mkdir -p /etc/systemd/system/getty@tty1.service.d
# Sin texto en pantalla: ni /etc/issue, ni prompt, ni "login:"; .hushlogin quita motd y último acceso.
cat > /etc/systemd/system/getty@tty1.service.d/override.conf <<EOF
[Service]
ExecStart=
ExecStart=-/usr/bin/agetty --autologin ${TARGET_USER} --noclear --skip-login --nonewline --noissue --nohints %I \$TERM
TTYVTDisallocate=no
EOF
touch "${TARGET_HOME}/.hushlogin"
chown "${TARGET_USER}:${TARGET_USER}" "${TARGET_HOME}/.hushlogin"

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
  # El log va a un archivo y no a tty1, para que no salga texto entre el splash y el escritorio.
  exec labwc > "${XDG_RUNTIME_DIR:-/tmp}/labwc.log" 2>&1
fi
EOF
chown "${TARGET_USER}:${TARGET_USER}" "${BASH_PROFILE}"

echo "==> Command OS layer installed."
