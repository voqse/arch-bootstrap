#!/usr/bin/env bash
# Hook: networkmanager
# Enables NetworkManager after installation.
# Wi-Fi backend configuration lives in hooks/iwd.sh — it runs only on hosts
# whose preset installs the Wi-Fi stack (iwd + wireless-regdb).
systemctl enable NetworkManager
