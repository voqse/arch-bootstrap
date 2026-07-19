#!/usr/bin/env bash
# Hook: pacman-contrib
# Enables the weekly paccache.timer (prunes old package versions from
# /var/cache/pacman/pkg, keeping the last 3 by default).
#
# The stock service runs a single "paccache -r $PACCACHE_ARGS", and the -u
# flag *restricts* a run to uninstalled packages — one invocation cannot both
# keep 3 versions of installed packages and purge uninstalled ones. A drop-in
# adds a second ExecStart (Type=oneshot allows it) that wipes the cache of
# packages no longer installed.
# Ref: https://wiki.archlinux.org/title/Pacman#Cleaning_the_package_cache

mkdir -p /etc/systemd/system/paccache.service.d
cat > /etc/systemd/system/paccache.service.d/uninstalled.conf <<'EOF'
[Service]
# Second pass: drop all cached versions of packages no longer installed
ExecStart=/usr/bin/paccache -ruk0
EOF

systemctl enable paccache.timer
