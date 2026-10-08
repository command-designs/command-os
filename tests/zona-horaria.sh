#!/usr/bin/env bash
# Command OS — prueba de la zona horaria sin pantalla: command-os-zona-horaria (lista, rechazos y qué
# reloj manda con el reloj del equipo en hora local o en UTC), la búsqueda y las sugerencias del
# asistente (lib/zonas.py) y la hora por la red (apply-system activa systemd-timesyncd).
#
# Se ejecuta como root en un Arch con el paquete instalado (GitHub Actions, ver
# .github/workflows/escritorio.yml). No toca el /etc/localtime de verdad: rutas y órdenes de reloj
# van cambiadas (COMMAND_OS_*). Sale con 1 si algo falla.
set -uo pipefail

fallos=0
ok() { echo "  ok   $*"; }
mal() { echo "  MAL  $*"; fallos=$((fallos + 1)); }
ZONAS=/usr/lib/command-os/zonas.py
T=$(mktemp -d)
trap 'rm -rf "${T}"' EXIT

# Órdenes de reloj falsas: apuntan lo que se les pide en ${T}/llamadas.
cat > "${T}/hwclock" <<EOF
#!/bin/sh
echo "hwclock \$*" >> "${T}/llamadas"
EOF
cat > "${T}/timedatectl" <<EOF
#!/bin/sh
case "\$1" in
  show) cat "${T}/sincronizada" 2>/dev/null ;;
  set-timezone) echo "timedatectl \$*" >> "${T}/llamadas"; ln -sfn /usr/share/zoneinfo/\$2 "${T}/localtime" ;;
esac
EOF
chmod +x "${T}/hwclock" "${T}/timedatectl"
touch "${T}/rtc"
export COMMAND_OS_LOCALTIME="${T}/localtime" COMMAND_OS_ADJTIME="${T}/adjtime" COMMAND_OS_RTC="${T}/rtc" \
  COMMAND_OS_HWCLOCK="${T}/hwclock" COMMAND_OS_TIMEDATECTL="${T}/timedatectl"
zona() { readlink "${T}/localtime"; }
reloj() { printf '0.0 0 0.0\n0\n%s\n' "$1" > "${T}/adjtime"; }
preparar() {  # preparar ZONA UTC|LOCAL yes|no
  ln -sfn "/usr/share/zoneinfo/$1" "${T}/localtime"
  reloj "$2"
  echo "$3" > "${T}/sincronizada"
  rm -f "${T}/llamadas"
}

echo "==> Lista"
lista=$(command-os-zona-horaria lista)
for z in UTC Europe/Madrid Atlantic/Canary America/New_York Asia/Kolkata; do
  grep -qxF "${z}" <<< "${lista}" && ok "en la lista: ${z}" || mal "falta ${z} en la lista"
done
[[ $(wc -l <<< "${lista}") -gt 300 ]] && ok "lista completa ($(wc -l <<< "${lista}") zonas)" || mal "lista corta"
grep -q '^#\|\.\.' <<< "${lista}" && mal "la lista lleva comentarios o rutas raras" || ok "sin comentarios ni rutas raras"
# El asistente (zonas.py) lee zone.tab por su cuenta (necesita el país): tiene que ser la misma lista.
if diff <(LC_ALL=C sort <<< "${lista}") <(python3 "${ZONAS}" lista | LC_ALL=C sort) >/dev/null; then
  ok "el asistente ofrece las mismas zonas que acepta la orden"
else
  mal "zonas.py y command-os-zona-horaria no tienen la misma lista"
fi

echo "==> Rechazos (no deben tocar nada)"
preparar Europe/Madrid UTC no
for z in ../../etc/passwd Foo/Bar Europe 'Europe/Madrid;rm' posixrules; do
  command-os-zona-horaria "${z}" >/dev/null 2>&1 && mal "acepta «${z}»" || ok "rechaza «${z}»"
done
[[ "$(zona)" == /usr/share/zoneinfo/Europe/Madrid ]] && ok "la zona sigue igual" || mal "un rechazo cambió la zona"

echo "==> Reloj del equipo en UTC (disco entero, imagen)"
preparar Europe/Madrid UTC no
command-os-zona-horaria America/New_York >/dev/null || mal "no cambia a America/New_York"
[[ "$(zona)" == /usr/share/zoneinfo/America/New_York ]] && ok "enlace a America/New_York" || mal "enlace: $(zona)"
[[ ! -e "${T}/llamadas" ]] && ok "no toca el reloj del equipo" || mal "tocó el reloj: $(cat "${T}/llamadas")"
ls "${T}"/localtime.command-os.* >/dev/null 2>&1 && mal "queda un enlace temporal" || ok "sin restos del enlace temporal"
command-os-zona-horaria UTC >/dev/null && [[ "$(zona)" == /usr/share/zoneinfo/UTC ]] && ok "UTC" || mal "UTC"

echo "==> Reloj en hora local (dual boot), hora sin sincronizar: manda el reloj del equipo"
preparar Europe/Madrid LOCAL no
command-os-zona-horaria America/Bogota >/dev/null || mal "no cambia a America/Bogota"
[[ "$(zona)" == /usr/share/zoneinfo/America/Bogota ]] && ok "enlace a America/Bogota" || mal "enlace: $(zona)"
[[ "$(cat "${T}/llamadas" 2>/dev/null)" == "hwclock --hctosys" ]] && ok "vuelve a leer el reloj del equipo" \
  || mal "esperaba hwclock --hctosys: $(cat "${T}/llamadas" 2>/dev/null)"

echo "==> Reloj en hora local, hora sincronizada por la red: manda el sistema"
preparar Europe/Madrid LOCAL yes
command-os-zona-horaria Europe/London >/dev/null || mal "no cambia a Europe/London"
[[ "$(cat "${T}/llamadas" 2>/dev/null)" == "timedatectl set-timezone Europe/London" ]] \
  && ok "timedatectl cambia la zona y escribe el reloj del equipo" || mal "llamadas: $(cat "${T}/llamadas" 2>/dev/null)"

echo "==> La misma zona: no hace nada"
preparar Europe/Madrid LOCAL no
command-os-zona-horaria Europe/Madrid >/dev/null && [[ ! -e "${T}/llamadas" ]] && ok "sin cambios ni lecturas" \
  || mal "con la misma zona tocó algo"
ln -sfn /usr/share/zoneinfo/Etc/UTC "${T}/localtime"
[[ "$(command-os-zona-horaria actual)" == UTC ]] && ok "Etc/UTC es UTC" || mal "actual con Etc/UTC"
[[ "$(python3 -c "import sys; sys.path.insert(0, '/usr/lib/command-os'); import zonas; print(zonas.actual())")" == UTC ]] \
  && ok "zonas.py la pregunta a la orden" || mal "zonas.actual()"
rm -f "${T}/localtime"
[[ "$(command-os-zona-horaria actual)" == UTC ]] && ok "sin /etc/localtime: UTC (como glibc)" || mal "sin /etc/localtime"

echo "==> /etc/localtime copiado en vez de enlazado: zona desconocida"
cp /usr/share/zoneinfo/Europe/Madrid "${T}/localtime"
rm -f "${T}/llamadas"; reloj UTC
[[ -z "$(command-os-zona-horaria actual)" ]] && ok "actual no inventa una zona" || mal "actual: $(command-os-zona-horaria actual)"
command-os-zona-horaria UTC >/dev/null && [[ "$(zona)" == /usr/share/zoneinfo/UTC ]] \
  && ok "pedir UTC sí la cambia (antes decía «ya es UTC»)" || mal "con un archivo copiado no cambia a UTC"

echo "==> Asistente: búsqueda y sugerencias (lib/zonas.py)"
buscar() { python3 "${ZONAS}" buscar "$@" | cut -f1; }
r=$(buscar 'espana' es_ES.UTF-8)
grep -qx Europe/Madrid <<< "${r}" && grep -qx Atlantic/Canary <<< "${r}" && ok "«espana» (sin tilde): Madrid y Canarias" \
  || mal "«espana»: ${r}"
grep -qx America/New_York <<< "$(buscar 'estados unidos' es_ES.UTF-8)" && ok "país en castellano (iso-codes)" \
  || mal "«estados unidos» no encuentra Nueva York"
grep -qx Europe/Madrid <<< "$(buscar spain en_US.UTF-8)" && ok "país en inglés" || mal "«spain»"
grep -qx Europe/Madrid <<< "$(buscar spain es_ES.UTF-8)" && ok "en castellano, también por el nombre en inglés" || mal "«spain» en castellano"
grep -qx Europe/Madrid <<< "$(buscar espana en_US.UTF-8)" && ok "en inglés, también por el nombre en castellano" || mal "«espana» en inglés"
grep -qx America/Bogota <<< "$(buscar 'BOGOTÁ')" && ok "ciudad, sin distinguir mayúsculas ni tildes" || mal "«BOGOTÁ»"
[[ "$(buscar 'buenos aires')" == America/Argentina/Buenos_Aires ]] && ok "ciudad de dos palabras" || mal "«buenos aires»"
[[ "$(buscar utc)" == UTC ]] && ok "UTC se encuentra (y solo UTC: no «Dutch»)" || mal "«utc»: $(buscar utc)"
grep -qx Europe/Madrid <<< "$(buscar 'madr')" && ok "con la palabra a medio escribir" || mal "«madr»"
[[ -z "$(buscar 'no-existe-xyz')" ]] && ok "sin resultados para algo que no existe" || mal "búsqueda sin filtrar"
[[ "$(python3 "${ZONAS}" sugerida 'de(nodeadkeys)')" == Europe/Berlin ]] && ok "teclado de(nodeadkeys) → Berlín" || mal "sugerida de"
[[ "$(python3 "${ZONAS}" sugerida es)" == Europe/Madrid ]] && ok "teclado es → Madrid" || mal "sugerida es"
[[ -z "$(python3 "${ZONAS}" sugerida es Atlantic/Canary)" ]] && ok "teclado es con Canarias: no la cambia (mismo país)" \
  || mal "teclado es cambia Canarias por Madrid"
[[ "$(python3 "${ZONAS}" sugerida es America/Bogota)" == Europe/Madrid ]] && ok "teclado es con Bogotá: propone Madrid" \
  || mal "sugerida es desde otro país"
[[ -z "$(python3 "${ZONAS}" sugerida us)$(python3 "${ZONAS}" sugerida latam)" ]] && ok "us y latam no sugieren (varias zonas)" \
  || mal "us o latam sugieren una zona"
[[ "$(python3 "${ZONAS}" diferencia Asia/Kolkata)" == "UTC+5:30" ]] && ok "diferencia UTC+5:30" || mal "Kolkata"
[[ "$(python3 "${ZONAS}" diferencia UTC)" == UTC ]] && ok "diferencia de UTC" || mal "UTC"
[[ "$(python3 "${ZONAS}" diferencia America/Bogota)" == "UTC−5" ]] && ok "diferencia negativa (UTC−5)" || mal "Bogotá"
unset COMMAND_OS_LOCALTIME COMMAND_OS_ADJTIME COMMAND_OS_RTC COMMAND_OS_HWCLOCK COMMAND_OS_TIMEDATECTL

echo "==> Hora por la red"
rm -f /var/lib/command-os/hora-por-red
systemctl disable systemd-timesyncd.service >/dev/null 2>&1
/usr/lib/command-os/apply-system >/dev/null 2>&1
systemctl is-enabled systemd-timesyncd.service >/dev/null 2>&1 && ok "systemd-timesyncd activado" || mal "timesyncd sin activar"
systemctl disable systemd-timesyncd.service >/dev/null 2>&1
/usr/lib/command-os/apply-system >/dev/null 2>&1
systemctl is-enabled systemd-timesyncd.service >/dev/null 2>&1 && mal "una actualización la vuelve a activar" \
  || ok "si se desactiva, una actualización la respeta"
# Con otro cliente de hora ya activo (aquí, una unidad chronyd de mentira), no se activa timesyncd.
printf '[Service]\nExecStart=/bin/true\n[Install]\nWantedBy=multi-user.target\n' > /etc/systemd/system/chronyd.service
systemctl enable chronyd.service >/dev/null 2>&1
rm -f /var/lib/command-os/hora-por-red
/usr/lib/command-os/apply-system >/dev/null 2>&1
systemctl is-enabled systemd-timesyncd.service >/dev/null 2>&1 && mal "activa timesyncd con chronyd ya activo" \
  || ok "con chronyd activo, timesyncd se queda como está"
systemctl disable chronyd.service >/dev/null 2>&1
rm -f /etc/systemd/system/chronyd.service

echo
if (( fallos )); then echo "==> ${fallos} fallo(s)"; exit 1; fi
echo "==> Todo bien"
