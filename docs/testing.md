# Ciclo de pruebas en VirtualBox

## Build inicial (una vez, ~15-25 min)

```
cd build/packer
packer init .
packer build -var iso_path=../iso/archlinux-x86_64.iso .
```

Esto crea la VM `command-os-dev` en VirtualBox, particiona el disco,
instala Arch base sin intervención manual, y corre `os/install.sh`
(paquetes + dotfiles de Hyprland). Al terminar, la VM queda registrada en
VirtualBox y apagada.

## Snapshot "clean-base"

Después del primer build exitoso, tomar un snapshot para poder volver a un
estado limpio sin repetir todo el proceso de instalación de Arch:

```
VBoxManage snapshot command-os-dev take clean-base
```

## Ciclo de iteración (dotfiles / paquetes)

1. Editar `os/packages.txt` o `os/dotfiles/...` en el repo.
2. Restaurar el snapshot limpio:
   ```
   VBoxManage snapshot command-os-dev restore clean-base
   ```
3. Arrancar la VM, copiar los archivos actualizados y re-correr el
   instalador (no hace falta reinstalar Arch base):
   ```
   VBoxManage startvm command-os-dev --type headless
   # esperar a que arranque, luego:
   scp -r os root@127.0.0.1:/tmp/command-os/os   # puerto ajustado según forwarding
   ssh root@127.0.0.1 '/tmp/command-os/os/install.sh'
   ```
4. Apagar o dejar corriendo la VM y abrirla en la ventana de VirtualBox
   (`VBoxManage startvm command-os-dev --type gui` o abrir la VM desde la
   GUI de VirtualBox) para revisar visualmente Hyprland/Waybar/dotfiles.

## Credenciales de desarrollo (no usar en producto final)

- Usuario: `deck` / password: `deck` (autologin en tty1, arranca Hyprland)
- `root` / password: `packer`, con `PermitRootLogin yes` — solo para este
  pipeline de build, hay que revisar/cerrar esto antes de considerar
  cualquier imagen "shippable".
