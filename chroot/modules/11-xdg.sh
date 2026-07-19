#!/usr/bin/env bash
# Chroot module — XDG user directories
# Disables xdg-user-dirs-update system-wide so login never auto-creates
# Desktop/Documents/Music/... in $HOME. The package is never listed in
# PACKAGES (it arrives only as a dependency of the desktop stack), so a hook
# would not fire — hence a conditional module. Skips silently when absent.
# Ref: https://wiki.archlinux.org/title/XDG_user_directories

section "Configuring XDG user directories"

if [[ -f /etc/xdg/user-dirs.conf ]]; then
    sed -i 's/^enabled=.*/enabled=False/' /etc/xdg/user-dirs.conf
    success "Disabled xdg-user-dirs auto-creation."
else
    info "xdg-user-dirs not installed; skipping."
fi
