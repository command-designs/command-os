#!/usr/bin/env bash
# Command OS — prueba de lo que hay detrás de Ajustes y del centro de control, sin pantalla: la red
# (lib/red.py con un nmcli de mentira: orden de las redes, conectar con y sin contraseña, y que la
# contraseña va por la entrada y nunca en la orden), el Bluetooth (lib/bt.py con bluetoothctl de
# mentira), el sonido y el brillo (lib/sonido.py con pamixer, pactl y brightnessctl de mentira) y el
# modo `datos` de command-os-about. Corre en cualquier Linux con python3 (GitHub Actions, ver
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
export PYTHONDONTWRITEBYTECODE=1 PYTHONPATH="${LIB}" XDG_CONFIG_HOME="${T}/config" LANG=es_ES.UTF-8
mkdir -p "${T}/bin"
export PATH="${T}/bin:${PATH}"
PY=$(command -v python3)
py() { "${PY}" -c "$1" "${@:2}"; }

echo "==> Red (lib/red.py)"
# nmcli de mentira: una tarjeta wlan0 y un cable, las redes de ${T}/redes, los perfiles de ${T}/perfiles;
# apunta cada orden en ${T}/nm-ordenes y, con --ask, lo que le llega por la entrada. NM_FALLA: patrón de
# las órdenes que salen con error.
cat > "${T}/bin/nmcli" <<EOF
#!/bin/sh
echo "nmcli \$*" >> "${T}/nm-ordenes"
case "\$*" in
  *--ask*) echo "entrada: \$(cat)" >> "${T}/nm-ordenes" ;;
esac
if [ -n "\${NM_FALLA:-}" ]; then
  case "\$*" in \${NM_FALLA}) exit 4 ;; esac
fi
case "\$*" in
  "-t -e no -f DEVICE,TYPE device") printf 'lo:loopback\nenp0s3:ethernet\nwlan0:wifi\n' ;;
  "-t -e no -f TYPE,STATE,CONNECTION device") printf 'loopback:connected (externally):lo\nethernet:connected:Conexión cableada 1\nwifi:connected:Oficina\n' ;;
  "radio wifi") echo enabled ;;
  *"device wifi list"*) cat "${T}/redes" ;;
  "-t -e no -f TYPE,NAME connection show") cat "${T}/perfiles" ;;
esac
exit 0
EOF
chmod +x "${T}/bin/nmcli"
printf '%s\n' ':45:WPA2:Casa' '*:70:WPA2:Oficina' ':90::Bar abierto' ':30:WPA2:Casa' ':50:WPA2:' \
  ':60:WPA1 WPA2:Red:con:dos puntos' > "${T}/redes"
printf '%s\n' '802-11-wireless:Oficina' '802-11-wireless:Casa' '802-3-ethernet:Conexión cableada 1' > "${T}/perfiles"

lista=$(py 'import red
for r in red.redes(): print(r["nombre"], r["senal"], int(r["segura"]), int(r["conectada"]), int(r["guardada"]), sep="|")')
esperada=$'Oficina|70|1|1|1\nBar abierto|90|0|0|0\nRed:con:dos puntos|60|1|0|0\nCasa|45|1|0|1'
[[ "${lista}" == "${esperada}" ]] \
  && ok "la conectada primero, luego por señal; cada red una vez, sin ocultas, con «:» en el nombre y las guardadas" \
  || mal "lista de redes: ${lista}"
[[ "$(py 'import red; print(red.dispositivo_wifi(), red.conexion(), red.cable())')" \
    == "wlan0 ('ethernet', 'Conexión cableada 1') (True, 'Conexión cableada 1')" ]] \
  && ok "tarjeta wi-fi, conexión y cable" || mal "dispositivo/conexión: $(py 'import red; print(red.dispositivo_wifi(), red.conexion(), red.cable())')"

# conectar NOMBRE [CONTRASEÑA]   -> imprime lo que devuelve red.conectar
conectar() {
  rm -f "${T}/nm-ordenes"
  py "import red, sys
r = next(x for x in red.redes() if x['nombre'] == sys.argv[1])
print(red.conectar(r, sys.argv[2] if len(sys.argv) > 2 else None))" "$@" 2>&1 | tail -1
}
ordenes() { grep -vE 'DEVICE,TYPE device$|wifi list|connection show$' "${T}/nm-ordenes" | tr '\n' ';'; }

r=$(conectar "Red:con:dos puntos")
[[ "${r}" == necesita_clave && -z "$(ordenes)" ]] && ok "red nueva con contraseña: la pide antes de tocar nada" \
  || mal "red nueva sin contraseña: ${r} $(ordenes)"
r=$(conectar "Red:con:dos puntos" 's3cr eto')
if [[ "${r}" == None && "$(ordenes)" == "nmcli --ask --wait 30 device wifi connect Red:con:dos puntos ifname wlan0;entrada: s3cr eto;" ]] \
    && [[ "$(grep -c 's3cr eto' "${T}/nm-ordenes")" == 1 ]]; then
  ok "con la contraseña: por la entrada de nmcli, nunca en la orden"
else
  mal "red nueva con contraseña: ${r} $(ordenes)"
fi
r=$(conectar "Bar abierto")
[[ "${r}" == None && "$(ordenes)" == "nmcli --wait 30 device wifi connect Bar abierto ifname wlan0;" ]] \
  && ok "red abierta: sin contraseña" || mal "red abierta: ${r} $(ordenes)"
r=$(conectar "Casa")
[[ "${r}" == None && "$(ordenes)" == "nmcli --wait 30 connection up id Casa;" ]] \
  && ok "red guardada: entra sin preguntar" || mal "red guardada: ${r} $(ordenes)"
r=$(NM_FALLA='*connection up*' conectar "Casa")
[[ "${r}" == necesita_clave ]] && ok "guardada cuya contraseña ya no vale: pide otra" || mal "guardada que falla: ${r}"
r=$(NM_FALLA='*--ask*' conectar "Casa" 'mala-clave')
[[ "${r}" == fallo && "$(ordenes)" == "nmcli --ask --wait 30 connection up id Casa;entrada: mala-clave;" ]] \
  && ok "contraseña que no vale: fallo, sin dejar la contraseña en la orden" || mal "contraseña mala: ${r} $(ordenes)"
rm -f "${T}/nm-ordenes"
py 'import red; print(red.olvidar("Red:con:dos puntos"), red.desconectar())' >/dev/null
[[ "$(ordenes)" == "nmcli connection delete id Red:con:dos puntos;nmcli device disconnect wlan0;" ]] \
  && ok "olvidar y desconectar" || mal "olvidar/desconectar: $(ordenes)"
[[ "$(PATH="${T}/vacio" py 'import red; print(red.dispositivo_wifi(), red.redes())')" == "None []" ]] \
  && ok "sin NetworkManager: ni tarjeta ni redes, sin errores" || mal "sin nmcli"

echo "==> Bluetooth (lib/bt.py)"
mkdir -p "${T}/sys-bt/hci0"
cat > "${T}/bin/bluetoothctl" <<EOF
#!/bin/sh
echo "bluetoothctl \$*" >> "${T}/bt-ordenes"
case "\$*" in
  show) echo "Controller 00:11:22:33:44:55"; echo "	Powered: \$(cat "${T}/bt-power")" ;;
  "devices Paired") printf 'Device AA:BB:CC:DD:EE:01 Auriculares de Ana\nDevice AA:BB:CC:DD:EE:02 Teclado\n' ;;
  "info AA:BB:CC:DD:EE:01") printf '	Icon: audio-headset\n	Connected: no\n' ;;
  "info AA:BB:CC:DD:EE:02") printf '	Icon: input-keyboard\n	Connected: yes\n' ;;
esac
exit 0
EOF
printf '#!/bin/sh\necho "rfkill $*" >> "%s/bt-ordenes"\n' "${T}" > "${T}/bin/rfkill"
chmod +x "${T}/bin/bluetoothctl" "${T}/bin/rfkill"
export COMMAND_OS_BLUETOOTH_SYS="${T}/sys-bt"
echo yes > "${T}/bt-power"
[[ "$(py 'import bt; print(bt.encendido(), [(d["nombre"], d["conectado"], d["icono"]) for d in bt.dispositivos()])')" \
    == "True [('Teclado', True, 'input-keyboard'), ('Auriculares de Ana', False, 'audio-headset')]" ]] \
  && ok "encendido y emparejados, los conectados primero" || mal "dispositivos: $(py 'import bt; print(bt.dispositivos())')"
rm -f "${T}/bt-ordenes"
py 'import bt; print(bt.poner(True), bt.accion("connect", "AA:BB:CC:DD:EE:01"), bt.accion("connect", "AA:BB; rm -rf /"))' \
  > "${T}/bt-res"
[[ "$(cat "${T}/bt-res")" == "True True False" && "$(tr '\n' ';' < "${T}/bt-ordenes")" \
    == "rfkill unblock bluetooth;bluetoothctl power on;bluetoothctl connect AA:BB:CC:DD:EE:01;" ]] \
  && ok "encender quita el bloqueo de rfkill; solo acepta direcciones de verdad" \
  || mal "acciones: $(cat "${T}/bt-res") $(tr '\n' ';' < "${T}/bt-ordenes")"
rm -f "${T}/bt-ordenes"
[[ "$(COMMAND_OS_BLUETOOTH_SYS="${T}/no-hay" py 'import bt; print(bt.encendido(), bt.dispositivos())')" == "False []" \
    && ! -e "${T}/bt-ordenes" ]] \
  && ok "sin adaptador: ni bluetoothctl (se quedaría esperando)" || mal "sin adaptador"

echo "==> Sonido y brillo (lib/sonido.py)"
cat > "${T}/bin/pamixer" <<EOF
#!/bin/sh
echo "pamixer \$*" >> "${T}/son-ordenes"
case "\$*" in
  --get-volume) echo 0; exit 1 ;;
  --get-mute) echo true; exit 0 ;;
  "--default-source --get-volume") echo 70 ;;
  "--default-source --get-mute") echo false; exit 1 ;;
esac
exit 0
EOF
cat > "${T}/bin/pactl" <<'EOF'
#!/bin/sh
case "$*" in
  "list sinks") printf 'Sink #52\n\tState: SUSPENDED\n\tName: alsa_output.analog\n\tDescription: Audio interno Estéreo analógico\n\tProperties:\n\t\tdevice.description = "otra"\nSink #60\n\tName: bluez_output.1\n\tDescription: Auriculares\n' ;;
  "list sources") printf 'Source #53\n\tName: alsa_output.analog.monitor\n\tDescription: Monitor\nSource #54\n\tName: alsa_input.mic\n\tDescription: Micrófono interno\n' ;;
  get-default-sink) echo bluez_output.1 ;;
  get-default-source) echo alsa_input.mic ;;
esac
EOF
cat > "${T}/bin/brightnessctl" <<EOF
#!/bin/sh
echo "brightnessctl \$*" >> "${T}/son-ordenes"
echo "intel_backlight,backlight,300,30%,1000"
EOF
chmod +x "${T}/bin/pamixer" "${T}/bin/pactl" "${T}/bin/brightnessctl"
[[ "$(py 'import sonido; print(sonido.volumen(), sonido.volumen(True))')" == "(0, True) (70, False)" ]] \
  && ok "volumen a 0 y silenciado (pamixer sale con 1 y vale lo que escribe)" \
  || mal "volumen: $(py 'import sonido; print(sonido.volumen(), sonido.volumen(True))')"
[[ "$(py 'import sonido; print(sonido.dispositivos(), sonido.dispositivos(True))')" \
    == "([('alsa_output.analog', 'Audio interno Estéreo analógico'), ('bluez_output.1', 'Auriculares')], 'bluez_output.1') ([('alsa_input.mic', 'Micrófono interno')], 'alsa_input.mic')" ]] \
  && ok "salidas y entradas con su descripción (tildes incluidas), sin los «monitor»" || mal "dispositivos: $(py 'import sonido; print(sonido.dispositivos(True))')"
mkdir -p "${T}/backlight/intel_backlight"
export COMMAND_OS_BACKLIGHT="${T}/backlight"
rm -f "${T}/son-ordenes"
[[ "$(py 'import sonido; print(sonido.brillo(), sonido.poner_brillo(0), sonido.poner_volumen(140))')" == "30 True True" ]] \
  && grep -q 'brightnessctl -q -c backlight set 5%' "${T}/son-ordenes" && grep -q 'pamixer --set-volume 100' "${T}/son-ordenes" \
  && ok "brillo leído; nunca por debajo del 5 % ni el volumen por encima del 100" || mal "brillo: $(cat "${T}/son-ordenes")"
[[ "$(COMMAND_OS_BACKLIGHT="${T}/no-hay" py 'import sonido; print(sonido.brillo())')" == None ]] \
  && ok "sin retroiluminación (monitor externo, VM): sin brillo" || mal "brillo sin retroiluminación"

echo "==> Acerca de, en datos (bin/command-os-about datos)"
cat > "${T}/bin/command-os-config" <<'EOF'
#!/bin/sh
echo /dev/null
EOF
printf '#!/bin/sh\nexit 1\n' > "${T}/bin/fastfetch"
chmod +x "${T}/bin/command-os-config" "${T}/bin/fastfetch"
sed "s|/usr/lib/command-os/textos.sh|${LIB}/textos.sh|" "${RAIZ}/os/bin/command-os-about" > "${T}/about"
datos=$(bash "${T}/about" datos 2>/dev/null)
if [[ "$(grep -c $'\t' <<< "${datos}")" -ge 9 ]] && grep -q $'^kernel\t' <<< "${datos}" && ! grep -q fastfetch <<< "${datos}"; then
  ok "una línea por dato, con un tabulador entre la etiqueta y el valor"
else
  mal "datos: ${datos}"
fi

echo
if (( fallos )); then echo "==> ${fallos} fallo(s)"; exit 1; fi
echo "==> Todo correcto"
