# Dual boot con Windows (PC/portátil x86_64)

Instala Command OS en el disco interno **junto a Windows**: al encender sale un menú de GRUB para
elegir Command OS o Windows. El script (`build/x86/install-dualboot.sh`) solo crea una partición
nueva en el espacio libre y añade GRUB a la partición EFI que ya existe; no formatea ni mueve
ninguna partición de Windows. Aun así, **haz copia de lo importante antes**.

Hace falta: un USB de ≥2 GB (se borra), conexión a internet (wifi o cable) y unos 30 GB libres.

## 1. En Windows

1. **Clave de recuperación de BitLocker** (si el disco está cifrado, casi siempre en portátiles con
   Windows 11): guárdala desde <https://account.microsoft.com/devices/recoverykey> o
   `manage-bde -protectors -get C:` (PowerShell como administrador). Después, suspende BitLocker
   para el primer reinicio: `manage-bde -protectors -disable C: -RebootCount 3`. Al cambiar el
   gestor de arranque, Windows puede pedir la clave una vez.
2. **Desactiva el inicio rápido**: Panel de control → Opciones de energía → "Elegir el
   comportamiento de los botones de inicio/apagado" → quitar "Activar inicio rápido". (Si no,
   Windows deja el disco a medio hibernar.)
3. **Libera espacio**: Administración de discos (`diskmgmt.msc`) → clic derecho en `C:` →
   "Reducir volumen" → al menos 30 000 MB (recomendado 60 000–100 000). Deja el hueco como
   **"No asignado"**: no crees ninguna partición en él.
4. **USB de Arch Linux**: descarga la ISO de <https://archlinux.org/download/> y grábala con
   [Rufus](https://rufus.ie) (esquema GPT, destino UEFI, modo imagen DD si lo pregunta).

## 2. En la BIOS/UEFI

Al encender, entra en la BIOS (F2, F10, Supr o Esc según la marca):
- **Secure Boot: desactivado** (la ISO de Arch y GRUB no van firmados).
- Modo de arranque **UEFI** (sin CSM/Legacy).
- Arranca desde el USB (menú de arranque: F12, F9, F8 o Esc según la marca).

## 3. En el USB de Arch (consola en vivo)

```sh
loadkeys es                       # teclado español en la consola
iwctl                             # solo wifi: station wlan0 connect "NombreDeLaRed", luego exit
ping -c2 archlinux.org            # comprobar internet

pacman -Sy --noconfirm git
git clone https://github.com/command-designs/command-os.git
# Repo privado: usuario de GitHub y, como contraseña, un token personal
# (github.com → Settings → Developer settings → Personal access tokens, permiso de lectura).

lsblk -o NAME,SIZE,MODEL          # identificar el disco interno (normalmente nvme0n1)
bash command-os/build/x86/install-dualboot.sh /dev/nvme0n1
```

El script enseña el disco, comprueba que hay un hueco libre de ≥30 GB y pide escribir `SI` antes de
tocar nada. Tarda 10–20 min (descarga ~2 GB de paquetes). Detecta solo si hay GPU NVIDIA.

Opciones (variables antes del comando, ej. `KB_LAYOUT=us bash ...`):

| Variable | Por defecto | Qué hace |
|---|---|---|
| `KB_LAYOUT` | `es` | Teclado en Hyprland y en la consola |
| `TIMEZONE` | `Europe/Madrid` | Zona horaria |
| `HOSTNAME_NEW` | `command-os` | Nombre del equipo |
| `VARIANT` | auto | `pc-nvidia` si hay GPU NVIDIA; vacío en Intel/AMD |

Al terminar: `reboot`, y quita el USB cuando se apague la pantalla.

## 4. Primer arranque

- Sale el menú de GRUB 5 s: **Command OS Linux** (por defecto) o **Windows**.
- Usuario `deck`, contraseña `deck`: entra directo al escritorio. Cámbiala con `passwd` en una
  terminal (Super+Enter).
- Wifi: `nmtui` en una terminal.
- La entrada **Windows** de GRUB arranca el gestor de Windows desde la partición EFI. Si fallara,
  Windows sigue disponible en el menú de arranque de la BIOS (F12/F9/Esc).
- Si el equipo arranca directo a Windows sin menú, en la BIOS pon **command-os** primero en el
  orden de arranque (algunos portátiles HP/Lenovo lo ignoran: ver abajo).
- Reactiva BitLocker en Windows si lo suspendiste: `manage-bde -protectors -enable C:`.

## Problemas conocidos

- **La BIOS vuelve a poner Windows primero** (algunos HP/Lenovo): en Windows, PowerShell como
  administrador: `bcdedit /set "{bootmgr}" path \EFI\command-os\grubx64.efi`. Se deshace con
  `bcdedit /set "{bootmgr}" path \EFI\Microsoft\Boot\bootmgfw.efi`.
- **El reloj de Windows se desfasa**: no debería; el instalador deja Linux con el reloj del equipo
  en hora local, como Windows (`/etc/adjtime` → `LOCAL`).
- **Volver a dejar solo Windows**: en Administración de discos, borrar la partición `command-os`;
  en PowerShell como administrador, `mountvol S: /s` y borrar `S:\EFI\command-os`.

## Qué se ha probado

El script se ha probado en WSL sobre un disco simulado con la misma tabla que un Windows real
(partición EFI con un `bootmgfw.efi` falso, MSR, partición de datos y hueco libre): crea la
partición en el hueco sin tocar las demás, instala todo, deja GRUB en `EFI/command-os/` sin tocar
`EFI/Microsoft` ni `EFI/Boot`, y el menú tiene la entrada de Windows. **No se ha probado todavía en un portátil real** (registro de la entrada UEFI, BitLocker,
drivers de wifi/gráfica concretos).
