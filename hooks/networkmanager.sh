#!/usr/bin/env bash
# Hook: networkmanager
# Enables NetworkManager service after installation.
systemctl enable NetworkManager

# Use iwd as the Wi-Fi backend for NetworkManager.
# iwd provides robust WPA3-SAE support; NetworkManager manages iwd internally
# so iwd.service must NOT be enabled separately.
# Ref: https://wiki.archlinux.org/title/NetworkManager#Using_iwd_as_the_Wi-Fi_backend
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/wifi_backend.ini <<'EOF'
[device]
wifi.backend=iwd
EOF
