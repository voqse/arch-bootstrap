#!/usr/bin/env bash
# Hook: tlp-rdw
# Enables the NetworkManager dispatcher service required by tlp-rdw and masks
# systemd-rfkill so TLP can manage radio device state without conflicts.
# Ref: https://wiki.archlinux.org/title/TLP
systemctl enable NetworkManager-dispatcher.service || \
    echo "Warning: failed to enable NetworkManager-dispatcher.service for tlp-rdw." >&2
systemctl mask systemd-rfkill.service systemd-rfkill.socket
