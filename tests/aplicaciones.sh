#!/usr/bin/env bash
# Command OS — prueba de lo que hace falta para instalar aplicaciones sin problemas, sin pantalla ni red:
# qué hace con cada descarga command-os-abrir-descarga (lib/descargas.py), que las asociaciones de tipos
# de serie (dotfiles/applications/mimeapps.list) cubren lo que se descarga, la orden de la tienda
# (command-os-tienda) y las copias del tema GTK que leen también las apps Flatpak (command-os-user-setup).
# Que cada aplicación de las asociaciones exista y declare su tipo lo mira tests/escritorio.sh, con los
# paquetes de verdad. Corre en cualquier Linux con python3 (GitHub Actions, ver
# .github/workflows/pruebas.yml). Sale con 1 si algo falla.
set -uo pipefail

RAIZ=$(cd "$(dirname "$0")/.." && pwd)
LIB="${RAIZ}/os/lib"
T=$(mktemp -d)
trap 'rm -rf "${T}"' EXIT
fallos=0
ok() { echo "  ok   $*"; }
mal() { echo "  MAL  $*"; fallos=$((fallos + 1)); }
# Sin bytecode: un os/lib/__pycache__ entraría en el paquete (PKGBUILD copia os/lib/*).
export PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="${LIB}"

echo "==> Descargas (lib/descargas.py)"
salida=$(python3 -c '
import descargas
for n in ["Obsidian-1.7.7.AppImage", "discord-0.0.80.deb", "zoom_x86_64.RPM", "flathub.flatpakrepo", "discord-0.0.80.tar.gz"]:
    print(descargas.tipo(n))')
[[ "${salida}" == $'appimage\ndebian\nrpm\nrepositorio\nNone' ]] && ok "tipo de cada descarga por su extensión" \
  || mal "tipos: ${salida}"
salida=$(python3 -c '
import descargas
for n in ["discord-0.0.80.deb", "google-chrome-stable_current_amd64.deb", "code_1.95.3-1731513102_amd64.deb",
          "steam_latest.deb", "zoom_x86_64.rpm", "Slack-v4.41.105.rpm", "1password-latest.deb"]:
    print(descargas.busqueda(n))')
[[ "${salida}" == $'discord\ngoogle chrome\ncode\nsteam\nzoom\nslack\n1password' ]] \
  && ok "nombre que se busca en la tienda (sin versión ni arquitectura)" || mal "búsquedas: ${salida//$'\n'/ | }"
elf() {  # elf ARCHIVO E_MACHINE   cabecera ELF de 64 bits, little endian
  python3 -c 'import struct, sys; open(sys.argv[1], "wb").write(b"\x7fELF\x02\x01\x01" + b"\0" * 11 + struct.pack("<H", int(sys.argv[2], 16)) + b"\0" * 40)' "$1" "$2"
}
elf "${T}/x86.AppImage" 3e
elf "${T}/arm.AppImage" b7
echo 'no soy un programa' > "${T}/texto.AppImage"
salida=$(python3 -c '
import descargas, sys
for n in sys.argv[1:]:
    print(descargas.maquina(n))' "${T}/x86.AppImage" "${T}/arm.AppImage" "${T}/texto.AppImage" "${T}/no-existe")
[[ "${salida}" == $'x86_64\naarch64\nNone\nNone' ]] && ok "procesador de un AppImage (ELF)" || mal "máquinas: ${salida}"
elf "${T}/i686.AppImage" 03
salida=$(python3 -c '
import descargas, sys
for n, este in zip(sys.argv[1::2], sys.argv[2::2]):
    print(descargas.otro_procesador(n, este))' "${T}/x86.AppImage" x86_64 "${T}/i686.AppImage" x86_64 \
  "${T}/arm.AppImage" x86_64 "${T}/x86.AppImage" aarch64 "${T}/texto.AppImage" x86_64)
[[ "${salida}" == $'None\nNone\naarch64\nx86_64\nNone' ]] \
  && ok "solo se rechaza lo que este procesador no ejecuta (32 bits del mismo sí)" || mal "otro procesador: ${salida}"
printf '[Flatpak Repo]\nTitle=GNOME Nightly\nUrl=https://nightly.gnome.org/repo/\nGPGKey=AAAA\n' > "${T}/gnome nightly.flatpakrepo"
printf '[Flatpak Repo]\nTitle=Local\nUrl=file:///tmp/repo\nGPGKey=AAAA\n' > "${T}/local.flatpakrepo"
printf 'no es un repositorio\n' > "${T}/roto.flatpakrepo"
printf '[Flatpak Repo]\nTitle=Sin firma\nUrl=https://ejemplo.org/repo/\n' > "${T}/sinfirma.flatpakrepo"
printf '[Flatpak Repo]\nTitle=Http\nUrl=http://ejemplo.org/repo/\nGPGKey=AAAA\n' > "${T}/http.flatpakrepo"
printf '[Flatpak Repo]\nTitle=Dos\nUrl=https://bueno.org/\n  https://malo.org/\nGPGKey=AAAA\n' > "${T}/varias.flatpakrepo"
printf '[Flatpak Repo]\nUrl=https://bueno.org/\nUrl=https://malo.org/\nGPGKey=AAAA\n' > "${T}/repetida.flatpakrepo"
# Para flatpak (GLib) «gpgkey» no es «GPGKey»: el remoto se añadiría sin firma.
printf '[Flatpak Repo]\nUrl=https://ejemplo.org/repo/\ngpgkey=AAAA\n' > "${T}/minusculas.flatpakrepo"
printf '[Flatpak Repo]\nUrl: https://ejemplo.org/repo/\nGPGKey=AAAA\n' > "${T}/dospuntos.flatpakrepo"
printf '[DEFAULT]\nGPGKey=AAAA\n[Flatpak Repo]\nUrl=https://ejemplo.org/repo/\n' > "${T}/heredada.flatpakrepo"
salida=$(python3 -c '
import descargas, sys
for n in sys.argv[1:]:
    print(descargas.repositorio(n))' "${T}/gnome nightly.flatpakrepo" "${T}"/{local,roto,sinfirma,http,varias,repetida,minusculas,dospuntos,heredada}.flatpakrepo)
[[ "${salida}" == $'(\'gnome-nightly\', \'GNOME Nightly\', \'https://nightly.gnome.org/repo/\')'"$(printf '\nNone%.0s' 1 2 3 4 5 6 7 8 9)" ]] \
  && ok "repositorio .flatpakrepo (nombre válido; fuera sin https, sin firma, roto, en varias líneas, repetido o con claves que GLib no lee igual)" \
  || mal "repositorios: ${salida//$'\n'/ | }"

echo "==> Asociaciones de tipos (mimeapps.list)"
MIME="${RAIZ}/os/dotfiles/applications/mimeapps.list"
DESKTOP="${RAIZ}/os/dotfiles/applications/dev.commandlab.AbrirDescarga.desktop"
falta=""
for tipo in application/zip application/x-compressed-tar application/x-xz-compressed-tar \
    application/x-zstd-compressed-tar application/x-7z-compressed application/vnd.rar \
    application/vnd.debian.binary-package application/x-rpm application/vnd.appimage \
    application/vnd.flatpak.ref application/vnd.flatpak.repo; do
  grep -q "^${tipo//./\\.}=" "${MIME}" || falta+=" ${tipo}"
done
[[ -z "${falta}" ]] && ok "comprimidos, paquetes, AppImage y Flatpak tienen aplicación de serie" || mal "sin aplicación:${falta}"
otros=$(sed -n '/^\[Default Applications\]/,/^\[/{/=/p}' "${MIME}" | cut -d= -f2 | sort -u \
  | grep -vxE 'thunar\.desktop|xarchiver\.desktop|io\.github\.kolunmi\.Bazaar\.desktop|dev\.commandlab\.AbrirDescarga\.desktop')
[[ -z "${otros}" ]] && ok "solo aplicaciones de serie (thunar, xarchiver, Bazaar, abrir descarga)" || mal "aplicaciones raras: ${otros}"
declara=$(sed -n 's/^MimeType=//p' "${DESKTOP}" | tr ';' '\n')
falta=""
for tipo in $(grep '=dev.commandlab.AbrirDescarga.desktop$' "${MIME}" | cut -d= -f1); do
  grep -qxF "${tipo}" <<< "${declara}" || falta+=" ${tipo}"
done
[[ -z "${falta}" ]] && ok "dev.commandlab.AbrirDescarga.desktop declara sus tipos" || mal "no declara:${falta}"
dup=$(sed -n '/=/p' "${MIME}" | cut -d= -f1 | sort | uniq -d)
[[ -z "${dup}" ]] && ok "ningún tipo dos veces" || mal "repetidos: ${dup}"

echo "==> Tienda (command-os-tienda)"
mkdir -p "${T}/bin"
printf '#!/bin/sh\nfor a in "$@"; do printf "[%%s]" "$a"; done\necho\n' > "${T}/bin/bazaar"
chmod +x "${T}/bin/bazaar"
TIENDA="${RAIZ}/os/bin/command-os-tienda"
[[ "$(PATH="${T}/bin:${PATH}" bash "${TIENDA}")" == "" ]] && ok "abrir la tienda" || mal "abrir"
[[ "$(PATH="${T}/bin:${PATH}" bash "${TIENDA}" buscar 'google chrome')" == "[--search-for][google chrome]" ]] \
  && ok "abrir la tienda buscando (un solo argumento)" || mal "buscar: $(PATH="${T}/bin:${PATH}" bash "${TIENDA}" buscar 'google chrome')"
PATH="${T}/bin:${PATH}" bash "${TIENDA}" otra 2>/dev/null; [[ $? == 2 ]] && ok "orden desconocida: error" || mal "orden desconocida"

echo "==> Tema GTK para las apps Flatpak (command-os-user-setup)"
SYS="${T}/sistema"
mkdir -p "${SYS}"/{gtk-3.0,gtk-4.0,nano} "${T}/casa"
for f in gtk-3.0/gtk.css gtk-3.0/settings.ini gtk-4.0/gtk.css gtk-4.0/settings.ini nano/nanorc; do
  echo "de serie 1: ${f}" > "${SYS}/${f}"
done
CFG="${T}/casa/.config"
mkdir -p "${CFG}/gtk-3.0" "${CFG}/command-os"
touch "${CFG}/command-os/layout-2"
ln -s "${SYS}/gtk-3.0/gtk.css" "${CFG}/gtk-3.0/gtk.css"  # una cuenta de antes: enlaces
preparar() { HOME="${T}/casa" XDG_CONFIG_HOME="${CFG}" COMMAND_OS_CONFIG="${SYS}" bash "${RAIZ}/os/bin/command-os-user-setup"; }
preparar
if [[ -f "${CFG}/gtk-3.0/gtk.css" && ! -L "${CFG}/gtk-3.0/gtk.css" && -f "${CFG}/gtk-4.0/settings.ini" ]] \
    && [[ "$(cat "${CFG}/gtk-3.0/gtk.css")" == "de serie 1: gtk-3.0/gtk.css" && -L "${CFG}/nano/nanorc" ]]; then
  ok "copias de la de serie (un enlace de antes pasa a copia; nano sigue con enlace)"
else
  mal "copias: $(ls -l "${CFG}/gtk-3.0" "${CFG}/gtk-4.0" 2>&1 | tr '\n' ' ')"
fi
echo 'mi tema' > "${CFG}/gtk-4.0/gtk.css"
for f in gtk-3.0/gtk.css gtk-4.0/gtk.css; do echo "de serie 2: ${f}" > "${SYS}/${f}"; done
preparar
[[ "$(cat "${CFG}/gtk-3.0/gtk.css")" == "de serie 2: gtk-3.0/gtk.css" ]] && ok "la copia sigue a la de serie cuando cambia" \
  || mal "no se puso al día: $(cat "${CFG}/gtk-3.0/gtk.css")"
[[ "$(cat "${CFG}/gtk-4.0/gtk.css")" == "mi tema" ]] && ok "un archivo del usuario no se toca" || mal "pisó el del usuario"
rm "${CFG}/command-os/gtk/gtk-3.0-settings.ini.sha256"
echo "de serie 3" > "${SYS}/gtk-3.0/settings.ini"
preparar
[[ "$(cat "${CFG}/gtk-3.0/settings.ini")" == "de serie 1: gtk-3.0/settings.ini" ]] \
  && ok "sin la suma de la copia, no se sabe si es del usuario: se deja" || mal "pisó una copia sin suma"
echo 'suma vieja' > "${CFG}/command-os/gtk/gtk-4.0-settings.ini.sha256"  # igual que la de serie, suma desfasada
preparar
echo "de serie 4" > "${SYS}/gtk-4.0/settings.ini"
preparar
[[ "$(cat "${CFG}/gtk-4.0/settings.ini")" == "de serie 4" && ! -e "${CFG}/gtk-4.0/settings.ini.nuevo" ]] \
  && ok "una copia igual a la de serie con la suma desfasada sigue al día" || mal "suma desfasada: $(cat "${CFG}/gtk-4.0/settings.ini")"
# Chaflanes de la marca: las hojas los buscan en chaflanes/, junto a ellas (en el sistema, un enlace).
mkdir -p "${SYS}/chaflanes"
echo '<svg>1</svg>' > "${SYS}/chaflanes/boton.svg"
for g in gtk-3.0 gtk-4.0; do ln -s ../chaflanes "${SYS}/${g}/chaflanes"; done
preparar
if [[ "$(cat "${CFG}/gtk-3.0/chaflanes/boton.svg" 2>/dev/null)" == '<svg>1</svg>' \
    && "$(cat "${CFG}/gtk-4.0/chaflanes/boton.svg" 2>/dev/null)" == '<svg>1</svg>' \
    && ! -L "${CFG}/gtk-3.0/chaflanes/boton.svg" ]]; then
  ok "chaflanes: copias junto a las hojas"
else
  mal "chaflanes: sin copiar ($(ls -l "${CFG}/gtk-3.0" 2>&1 | tr '\n' ' '))"
fi
echo '<svg>2</svg>' > "${SYS}/chaflanes/boton.svg"
preparar
[[ "$(cat "${CFG}/gtk-4.0/chaflanes/boton.svg")" == '<svg>2</svg>' ]] && ok "chaflanes: siguen a los de serie" \
  || mal "chaflanes: no se pusieron al día"

echo
if (( fallos )); then echo "==> ${fallos} fallo(s)"; exit 1; fi
echo "==> Todo correcto"
