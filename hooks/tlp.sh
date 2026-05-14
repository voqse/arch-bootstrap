#!/usr/bin/env bash
# Hook: tlp
# Enables the main TLP power-management service after installation and masks
# systemd-rfkill so TLP can manage radio device state without conflicts.
# Ref: https://wiki.archlinux.org/title/TLP
systemctl enable tlp.service
systemctl mask systemd-rfkill.service systemd-rfkill.socket
