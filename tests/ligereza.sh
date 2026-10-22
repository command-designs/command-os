#!/usr/bin/env bash
# Command OS — prueba del medidor de ligereza (bin/command-os-medir) sobre un /proc de mentira: cuándo da el
# escritorio por listo y cuánto espera, la memoria usada, PSS y RSS sumados por programa (los intérpretes con el
# nombre del script, los hilos del núcleo juntos), los tics de CPU durante la ventana, que no cuenta su propia
# sesión ni la de SSH (pero sí la terminal del escritorio), los tiempos de systemd-analyze y que se rinde si no
# hay escritorio. Corre en cualquier Linux con bash y awk (GitHub Actions). Sale con 1 si algo falla.
set -uo pipefail

RAIZ=$(cd "$(dirname "$0")/.." && pwd)
MEDIR="${RAIZ}/os/bin/command-os-medir"
T=$(mktemp -d)
trap 'rm -rf "${T}"' EXIT
fallos=0
ok() { echo "  ok   $*"; }
mal() { echo "  MAL  $*"; fallos=$((fallos + 1)); }
P="${T}/proc"

# proceso PID PPID SID COMM CMDLINE(separado por |, vacío = hilo del núcleo) INICIO_TICS UTIME STIME [PSS RSS]
proceso() {
  local d="${P}/$1"
  mkdir -p "${d}"
  printf '%s\n' "$4" > "${d}/comm"
  printf '%s' "$5" | tr '|' '\0' > "${d}/cmdline"
  [ -n "$5" ] && printf '\0' >> "${d}/cmdline"
  printf '%s (%s) S %s %s %s 0 -1 4194560 100 0 0 0 %s %s 0 0 20 0 1 0 %s 1000 100\n' \
    "$1" "$4" "$2" "$3" "$3" "$7" "$8" "$6" > "${d}/stat"
  if [ $# -ge 10 ]; then
    printf '55d0-7ffe ---p 00000000 00:00 0  [rollup]\nRss:  %s kB\nPss:  %s kB\nPss_Dirty:  1 kB\n' "${10}" "$9" \
      > "${d}/smaps_rollup"
  fi
}
# tics PID UTIME STIME: cambia los tics de un proceso (lo que pasa durante la ventana)
tics() { sed -i -E "s/^($1 \\([^)]*\\) ([^ ]+ ){11})[0-9]+ [0-9]+ /\\1$2 $3 /" "${P}/$1/stat"; }

montar() {
  rm -rf "${P}"; mkdir -p "${P}"
  printf '%s 500.00\n' "${1:-300.00}" > "${P}/uptime"
  printf 'MemTotal:  4000000 kB\nMemFree:  2000000 kB\nMemAvailable:  3000000 kB\n' > "${P}/meminfo"
  printf 'cpu  100 0 200 5000 10 30 40 0 0 0\ncpu0 1\ncpu1 1\ncpu2 1\ncpu3 1\n' > "${P}/stat"
  proceso 1 0 1 systemd '/usr/lib/systemd/systemd|--switched-root' 10 5 5 2048 8000
  proceso 2 0 0 kthreadd '' 10 0 0
  proceso 15 2 0 ksoftirqd/0 '' 10 3 0
  proceso 50 1 50 sshd '/usr/bin/sshd|-D' 200 1 1 2048 8000
  proceso 100 1 100 labwc 'labwc|--merge-config' 1000 50 50 102400 136000
  proceso 101 1 100 waybar 'waybar|--config|x' 1500 10 10 30720 60000
  proceso 102 1 100 python3 'python3|/usr/lib/command-os/pantallas.py|vigilar' 1500 1 1 10240 18000
  proceso 103 1 100 xdg-desktop-por '/usr/lib/xdg-desktop-portal' 1500 0 0 1024 30000
  proceso 104 1 100 xdg-desktop-por '/usr/lib/xdg-desktop-portal-gtk' 1500 0 0 1024 30000
  proceso 110 100 110 kitty 'kitty' 2000 4 4 20480 40000
  proceso 111 110 111 bash 'bash' 2000 1 1 5000 6000
  # la conexión SSH desde la que se mide: sshd → sshd-session → sshd-session → bash → sudo → bash medir
  proceso 296 50 296 sshd-session 'sshd-session: deck [priv]' 3000 1 1 5000 9000
  proceso 297 296 296 sshd-session 'sshd-session: deck@notty' 3000 1 1 5000 9000
  proceso 298 297 298 bash 'bash|-c|x' 3000 1 1 5000 6000
  proceso 299 298 299 sudo 'sudo|-S|bash' 3000 1 1 5000 6000
  proceso 300 299 299 bash 'bash|/tmp/command-os-medir|--tsv' 3000 100 0 5000 6000
}

# Lo que pasa durante la ventana (la llamada a «dormir» con los segundos de la ventana): suben los tics
cat > "${T}/dormir" <<EOF
#!/usr/bin/env bash
echo "\$1" >> "${T}/dormido"
[ "\$1" = 60 ] || exit 0
P="${P}"
$(declare -f tics)
printf 'cpu  110 0 220 5100 10 90 70 0 0 0\ncpu0 1\ncpu1 1\ncpu2 1\ncpu3 1\n' > "\${P}/stat"
tics 100 80 70
tics 101 15 15
tics 300 400 0
tics 296 50 50
tics 15 9 0
EOF
chmod +x "${T}/dormir"
cat > "${T}/analyze" <<'EOF'
#!/bin/sh
echo 'Startup finished in 11.697s (kernel) + 1.814s (initrd) + 1min 32.844s (userspace) = 1min 46.356s '
echo 'graphical.target reached after 1min 32.841s in userspace.'
EOF
chmod +x "${T}/analyze"

medir() {
  rm -f "${T}/dormido"
  COMMAND_OS_PROC="${P}" COMMAND_OS_HZ=100 COMMAND_OS_ANALYZE="${T}/analyze" COMMAND_OS_DORMIR="${T}/dormir" \
    bash "${MEDIR}" --tsv "$@" 2> "${T}/err"
}
campo() { awk -F'\t' -v c="$1" '$1 == "R" && $2 == c { print $3 }' "${T}/out"; }
prog() { awk -F'\t' -v n="$1" '$1 == "P" && $2 == n { print $3, $4, $5, $6 }' "${T}/out"; }
igual() { if [ "$2" = "$3" ]; then ok "$1"; else mal "$1: «$2», se esperaba «$3»"; fi; }

echo "== medida por SSH (uptime 100 s: espera a los 120 s del escritorio)"
montar 100.00
COMMAND_OS_YO=300 medir > "${T}/out" || mal "sale con error: $(cat "${T}/err")"
igual "escritorio listo cuando arranca el último (Waybar)" "$(campo escritorio_s) $(campo sesion)" "15.0 labwc"
igual "espera hasta 120 s después del escritorio y mide 60" "$(tr '\n' ' ' < "${T}/dormido")" "35 60 "
igual "memoria usada = MemTotal − MemAvailable" "$(campo mem_usada_mb)" "976"
igual "tiempos de systemd-analyze" "$(campo kernel_s) $(campo initrd_s) $(campo userspace_s)" "11.7 1.8 92.8"
igual "PSS y RSS del compositor y sus tics en la ventana" "$(prog labwc)" "1 102400 136000 50"
igual "procesos con el mismo nombre, juntos" "$(prog xdg-desktop-por)" "2 2048 60000 0"
igual "un script de Python, con el nombre del script" "$(prog pantallas.py)" "1 10240 18000 0"
igual "hilos del núcleo juntos, sin memoria" "$(prog '[núcleo]')" "2 0 0 6"
igual "la terminal del escritorio sí cuenta" "$(prog kitty)" "1 20480 40000 0"
igual "sshd (el servicio) sí cuenta" "$(prog sshd)" "1 2048 8000 0"
igual "ni su sesión, ni sudo, ni la de SSH" "$(prog sudo)$(prog sshd-session)$(prog command-os-medir)" ""
igual "bash: solo el de la terminal" "$(prog bash)" "1 5000 6000 0"
igual "PSS total sin lo excluido" "$(campo pss_total_mb)" "170"
igual "tics de procesos por minuto" "$(campo procesos_tics_min)" "66"
igual "tics del sistema por minuto (sin idle ni iowait)" "$(campo cpu_tics_min) $(campo cpu_pct)" "120 0.50"
igual "de más a menos PSS" "$(awk -F'\t' '$1 == "P" { print $2; exit }' "${T}/out")" "labwc"

echo "== ya pasaron los 120 s: no espera"
montar 300.00
COMMAND_OS_YO=300 medir > "${T}/out"
igual "solo duerme la ventana" "$(tr '\n' ' ' < "${T}/dormido")" "60 "
COMMAND_OS_YO=300 medir --espera 300 --ventana 60 > "${T}/out"
igual "--espera cambia la espera" "$(tr '\n' ' ' < "${T}/dormido")" "15 60 "

echo "== sin escritorio"
montar 1000.00
rm -rf "${P}/101"
if COMMAND_OS_LIMITE=900 COMMAND_OS_YO=300 medir > "${T}/out"; then mal "sin Waybar no debía medir"
elif grep -q "no hay escritorio" "${T}/err"; then ok "se rinde y lo dice"
else mal "error inesperado: $(cat "${T}/err")"; fi

echo "== resumen legible"
montar 300.00
if COMMAND_OS_PROC="${P}" COMMAND_OS_HZ=100 COMMAND_OS_ANALYZE="${T}/analyze" COMMAND_OS_DORMIR="${T}/dormir" \
  COMMAND_OS_YO=300 bash "${MEDIR}" > "${T}/out" 2>/dev/null && grep -q "^Sesión labwc · escritorio listo a los 15.0 s" "${T}/out"; then
  ok "sin --tsv, una tabla"
else mal "sin --tsv no sale el resumen"; fi

[ "${fallos}" = 0 ] && echo "ligereza: todo bien" || { echo "ligereza: ${fallos} fallos"; exit 1; }
