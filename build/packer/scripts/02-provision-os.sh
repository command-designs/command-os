#!/usr/bin/env bash
# Runs on the freshly installed system (over SSH, as root) after the reboot
# from 01-base-install.sh. Installs our curated OS layer.
set -euxo pipefail

chmod +x /tmp/command-os/os/install.sh
# VM de desarrollo: se entra por SSH, así que install.sh no debe apagarlo, y lleva la cuenta de
# desarrollo deck/deck con inicio automático (sin asistente de primer arranque).
COMMAND_OS_SSH=1 COMMAND_OS_DEV_USER=deck /tmp/command-os/os/install.sh
