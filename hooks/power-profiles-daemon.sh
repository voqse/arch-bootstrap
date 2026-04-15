#!/usr/bin/env bash
# Hook: power-profiles-daemon
# Enables the power-profiles-daemon for battery and performance profile management.
# Ref: https://wiki.archlinux.org/title/Power_management#Power_profiles
systemctl enable power-profiles-daemon
