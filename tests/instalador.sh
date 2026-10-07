#!/usr/bin/env bash
# Command OS — prueba del instalador publicado (docs/instalacion.md § 2):
#   - instalar-command-os.sh lleva la huella de os/pacman/command-os.fingerprint, que es la de la
#     clave pública que se publica;
#   - empaquetar-instalador.sh mete lo necesario para instalar y nada más;
#   - instalar-command-os.sh solo ejecuta el instalador con una firma buena de esa clave: rechaza uno
#     alterado, uno sin firma y uno firmado (y publicado con su clave) por otra.
# Las firmas se hacen con claves de prueba generadas aquí (la de verdad no sale de su sitio).
#
# Como root (instalar-command-os.sh lo exige), sin tocar discos: GitHub Actions (pruebas.yml).
# Necesita git, gpg, tar y curl. Sale con 1 si algo falla.
set -uo pipefail

REPO=$(cd "$(dirname "$0")/.." && pwd)
ARRANQUE="${REPO}/build/x86/instalar-command-os.sh"
fallos=0
ok() { echo "  ok   $*"; }
mal() { echo "  MAL  $*"; fallos=$((fallos + 1)); }

tmp=$(mktemp -d)
trap 'rm -rf "${tmp}"' EXIT
export GNUPGHOME="${tmp}/gnupg"
install -d -m 700 "${GNUPGHOME}"

echo "==> Huella de la clave"
huella_arranque=$(sed -nE 's/^HUELLA=([0-9A-F]{40})$/\1/p' "${ARRANQUE}")
huella_repo=$(tr -d '[:space:]' < "${REPO}/os/pacman/command-os.fingerprint")
[[ -n "${huella_arranque}" && "${huella_arranque}" == "${huella_repo}" ]] \
  && ok "instalar-command-os.sh lleva la huella de os/pacman/command-os.fingerprint" \
  || mal "huella distinta: ${huella_arranque:-ninguna} / ${huella_repo}"
huella_clave=$(gpg --batch --with-colons --import-options show-only --import "${REPO}/os/pacman/command-os.gpg" 2>/dev/null \
  | awk -F: '$1 == "fpr" { print $10; exit }')
[[ "${huella_clave}" == "${huella_repo}" ]] && ok "la clave pública que se publica es esa" \
  || mal "os/pacman/command-os.gpg es otra clave (${huella_clave:-ilegible})"

echo "==> Lo que lleva el instalador (empaquetar-instalador.sh)"
if bash "${REPO}/build/x86/empaquetar-instalador.sh" "${tmp}/real.tar.gz" 2026.01.01.0000 >/dev/null; then
  ok "se empaqueta"
else
  mal "no se empaqueta"
fi
contenido=$(tar -tzf "${tmp}/real.tar.gz" 2>/dev/null)
for f in PUBLICADO build/x86/instalar.sh build/x86/install-disco.sh build/x86/install-dualboot.sh \
  build/x86/lib.sh os/install.sh os/pkg/PKGBUILD os/pacman/command-os.gpg os/lib/apply-repos; do
  grep -qx "command-os/${f}" <<< "${contenido}" && ok "lleva ${f}" || mal "falta ${f}"
done
sobra=$(grep -vE '^command-os/(PUBLICADO|build/|build/x86/|build/x86/(instalar|install-disco|install-dualboot)\.sh|build/x86/lib\.sh|os/.*)$' <<< "${contenido}" | grep -v '^command-os/$')
[[ -z "${sobra}" ]] && ok "no lleva nada más" || mal "lleva de más: $(head -3 <<< "${sobra}" | tr '\n' ' ')"
tar -xzf "${tmp}/real.tar.gz" -C "${tmp}" command-os/PUBLICADO command-os/build/x86/lib.sh
[[ "$(cat "${tmp}/command-os/PUBLICADO")" == 2026.01.01.0000 ]] && ok "PUBLICADO con la versión" || mal "PUBLICADO"
grep -q $'\r' "${tmp}/command-os/build/x86/lib.sh" && mal "lib.sh con CRLF" || ok "scripts con LF"

echo "==> Firma (claves de prueba)"
nueva_clave() {  # nueva_clave NOMBRE -> huella
  gpg --batch --passphrase '' --quick-gen-key "$1 <$1@prueba.invalid>" ed25519 sign never >/dev/null 2>&1
  gpg --batch --with-colons --list-keys "$1" 2>/dev/null | awk -F: '$1 == "fpr" { print $10; exit }'
}
buena=$(nueva_clave buena)
otra=$(nueva_clave otra)
[[ -n "${buena}" && -n "${otra}" ]] || { echo "no se pudieron generar las claves de prueba" >&2; exit 1; }
# Un instalador de mentira: dice que se ha ejecutado y con qué argumentos.
install -d "${tmp}/falso/command-os/build/x86"
printf '#!/usr/bin/env bash\necho "INSTALADOR EJECUTADO $* idioma=${COMMAND_OS_IDIOMA:-}"\n' \
  > "${tmp}/falso/command-os/build/x86/instalar.sh"
echo 2026.01.01.0000 > "${tmp}/falso/command-os/PUBLICADO"
tar -czf "${tmp}/falso.tar.gz" -C "${tmp}/falso" command-os
# El script del USB, con la huella de la clave de prueba buena.
sed -E "s/^HUELLA=.*/HUELLA=${buena}/" "${ARRANQUE}" > "${tmp}/arranque.sh"

publicar() {  # publicar DIR CLAVE_QUE_FIRMA CLAVE_PUBLICADA [alterar|sin-firma]
  local d=$1
  rm -rf "${d}"; install -d "${d}"
  cp "${tmp}/falso.tar.gz" "${d}/command-os-instalador.tar.gz"
  gpg --batch --yes --local-user "$2" --detach-sign -o "${d}/command-os-instalador.tar.gz.sig" \
    "${d}/command-os-instalador.tar.gz" 2>/dev/null
  gpg --batch --export "$3" > "${d}/command-os.gpg"
  case "${4:-}" in
    alterar) printf 'x' >> "${d}/command-os-instalador.tar.gz" ;;
    sin-firma) rm -f "${d}/command-os-instalador.tar.gz.sig" ;;
  esac
}
probar() {  # probar DIR [IDIOMA] -> salida del script del USB (con un anillo de claves vacío, como
  # en el USB). Sin IDIOMA, contesta la pregunta del idioma por la entrada estándar (entrada aparte).
  rm -rf "${tmp}/destino"
  env -u GNUPGHOME COMMAND_OS_FUERA_DEL_USB=1 COMMAND_OS_INSTALADOR_URL="file://$1" ${2:+COMMAND_OS_IDIOMA=$2} \
    COMMAND_OS_INSTALADOR_DIR="${tmp}/destino" bash "${tmp}/arranque.sh" uno dos 2>&1
}

publicar "${tmp}/p1" "${buena}" "${buena}"
salida=$(probar "${tmp}/p1" es </dev/null)
grep -q 'INSTALADOR EJECUTADO uno dos idioma=es' <<< "${salida}" && ok "firma buena: lo ejecuta (con sus argumentos)" \
  || mal "firma buena: no lo ejecuta: ${salida}"
# El idioma se pregunta antes de nada y pasa al asistente; sus mensajes ya salen en ese idioma.
salida=$(probar "${tmp}/p1" <<< "2")
grep -q 'Downloading the Command OS installer' <<< "${salida}" && grep -q 'INSTALADOR EJECUTADO uno dos idioma=en' <<< "${salida}" \
  && ok "idioma elegido (2: English): mensajes en inglés y COMMAND_OS_IDIOMA=en al asistente" \
  || mal "elegir el idioma: ${salida}"
salida=$(probar "${tmp}/p1" <<< "")
grep -q 'Descargando el instalador' <<< "${salida}" && grep -q 'idioma=es' <<< "${salida}" \
  && ok "idioma por defecto (Intro): castellano" || mal "idioma por defecto: ${salida}"
salida=$(probar "${tmp}/p1" fr </dev/null)
grep -q 'INSTALADOR EJECUTADO' <<< "${salida}" && mal "acepta COMMAND_OS_IDIOMA=fr" || ok "rechaza COMMAND_OS_IDIOMA=fr"

for caso in alterar sin-firma otra-clave; do
  if [[ "${caso}" == otra-clave ]]; then
    publicar "${tmp}/p2" "${otra}" "${otra}"   # alguien que sustituye la clave y la firma
  else
    publicar "${tmp}/p2" "${buena}" "${buena}" "${caso}"
  fi
  salida=$(probar "${tmp}/p2" es </dev/null)
  if grep -q 'INSTALADOR EJECUTADO' <<< "${salida}" || [[ -e "${tmp}/destino/command-os" ]]; then
    mal "${caso}: lo ejecuta o lo extrae"
  else
    ok "${caso}: no ejecuta ni extrae nada"
  fi
done

echo "==> Mensajes del instalador en inglés"
# Como en el USB de Arch: solo el locale C.UTF-8 (con él gettext no traduce) y sin el catálogo de un
# Command OS instalado. cargar_idioma genera el locale y compila el de os/po/ de este árbol.
salida=$(env -i PATH="${PATH}" LANG=C.UTF-8 COMMAND_OS_LOCALE_DIR="${tmp}/locale" bash -c '
  source "$1/build/x86/lib.sh"
  COMMAND_OS_IDIOMA=en cargar_idioma
  echo "$(t "cancelado: no se ha tocado nada")|$(t "SI")|${IDIOMA}|${KB_DEFECTO}"' _ "${REPO}" 2>&1)
[[ "${salida}" == "cancelled: nothing has been touched|YES|en_US.UTF-8|us" ]] \
  && ok "en inglés: mensajes traducidos, sistema en_US.UTF-8 y teclado us" || mal "en inglés: ${salida}"
# En castellano no traduce aunque el entorno esté en inglés y ya haya un catálogo compilado (el de arriba).
salida=$(env -i PATH="${PATH}" LANG=en_US.UTF-8 COMMAND_OS_LOCALE_DIR="${tmp}/locale" bash -c '
  source "$1/build/x86/lib.sh"; cargar_idioma
  echo "$(t "cancelado: no se ha tocado nada")|${IDIOMA}|${KB_DEFECTO}"' _ "${REPO}" 2>&1)
[[ "${salida}" == "cancelado: no se ha tocado nada|es_ES.UTF-8|es" ]] \
  && ok "sin idioma: castellano, es_ES.UTF-8 y teclado es" || mal "sin idioma: ${salida}"

echo
if (( fallos )); then echo "==> ${fallos} fallo(s)"; exit 1; fi
echo "==> Todo correcto"
