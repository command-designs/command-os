#!/usr/bin/env bash
# Runs on the freshly installed system (over SSH, as root) after the reboot
# from 01-base-install.sh. Installs our curated OS layer.
set -euxo pipefail

chmod +x /tmp/command-os/os/install.sh
/tmp/command-os/os/install.sh
