#!/usr/bin/env bash
# Command OS — empaqueta el instalador que se publica (lo usa .github/workflows/publicar.yml):
#   bash build/x86/empaquetar-instalador.sh SALIDA.tar.gz VERSION
# Deja command-os/ con los scripts de instalación de build/x86 y el árbol os/ (lo mismo que va dentro
# del paquete, que ya es público) más PUBLICADO con la versión. Con PUBLICADO, el instalador instala
# el paquete firmado del repositorio en vez de construirlo (lib.sh: configure_system).
#
# Sale de git (git archive): solo lo que está en el repositorio, con los finales de línea de
# .gitattributes; nada de discos de VM, llaves ni archivos sin seguimiento. Lo firma quien lo publica;
# instalar-command-os.sh comprueba la firma antes de ejecutar nada.
set -euo pipefail

SALIDA=${1:?uso: empaquetar-instalador.sh SALIDA.tar.gz VERSION}
VERSION=${2:?falta la versión}
REPO=$(cd "$(dirname "$0")/../.." && pwd)
# Lo que hace falta para instalar (instalar.sh y lo que llama) y nada más de build/.
ARCHIVOS=(build/x86/instalar.sh build/x86/install-disco.sh build/x86/install-dualboot.sh build/x86/lib.sh os)

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
git -C "${REPO}" archive --format=tar --prefix=command-os/ HEAD "${ARCHIVOS[@]}" | tar -x -C "${tmp}"
echo "${VERSION}" > "${tmp}/command-os/PUBLICADO"
# Reproducible: mismo orden, dueño y fecha en cada empaquetado.
tar --sort=name --owner=0 --group=0 --numeric-owner --mtime='@0' -czf "${SALIDA}" -C "${tmp}" command-os
echo "==> Instalador ${VERSION}: ${SALIDA} ($(du -h "${SALIDA}" | cut -f1))"
