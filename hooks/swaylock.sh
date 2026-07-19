#!/usr/bin/env bash
# Hook: swaylock
# Makes a successful swaylock unlock also unlock the GNOME keyring, so
# keyring-backed apps don't re-prompt after the screen was locked.
# Desktop-only by construction: the hook runs only when the preset installs
# swaylock (config/desktop.conf); headless hosts have neither swaylock nor a
# session that could unlock a keyring.
# NOTE: /etc/pam.d/swaylock is not a pacman backup file — a package update
# may rewrite it and drop this line; the hook is idempotent, re-run it then.
# Ref: https://wiki.archlinux.org/title/GNOME/Keyring#PAM_step

if ! grep -q pam_gnome_keyring /etc/pam.d/swaylock 2>/dev/null; then
    printf 'auth      optional  pam_gnome_keyring.so\n' >> /etc/pam.d/swaylock
fi
