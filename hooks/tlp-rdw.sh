#!/usr/bin/env bash
# Hook: tlp-rdw
# Enables the NetworkManager dispatcher service required by tlp-rdw.
# systemd-rfkill is deliberately NOT masked: masking it breaks rfkill state
# persistence across reboots for every consumer, which outweighs the
# theoretical TLP race it was meant to prevent (decision 2026-07-19).
# Ref: https://wiki.archlinux.org/title/TLP
systemctl enable NetworkManager-dispatcher.service || \
    echo "Warning: failed to enable NetworkManager-dispatcher.service for tlp-rdw." >&2
