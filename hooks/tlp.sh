#!/usr/bin/env bash
# Hook: tlp
# Enables the main TLP power-management service after installation.
# Ref: https://wiki.archlinux.org/title/TLP
systemctl enable tlp.service
