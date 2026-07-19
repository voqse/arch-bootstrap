#!/usr/bin/env bash
# Hook: pacman-contrib
# Enables the weekly paccache.timer (prunes old package versions from
# /var/cache/pacman/pkg, keeping the last 3 by default). Retention is
# tunable via PACCACHE_ARGS in /etc/conf.d/pacman-contrib if ever needed.
# Ref: https://wiki.archlinux.org/title/Pacman#Cleaning_the_package_cache

systemctl enable paccache.timer
