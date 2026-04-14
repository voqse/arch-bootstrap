#!/usr/bin/env bash
# =============================================================================
# Chroot module — Initramfs
# mkinitcpio is already run by the linux package post-install, but we
# re-run it here to ensure a clean image with the current configuration.
# Ref: https://wiki.archlinux.org/title/Installation_guide#Initramfs
# =============================================================================

chroot_initramfs() {
    section "Initramfs"

    # Insert the appropriate plymouth hook when plymouth is installed.
    # Modern mkinitcpio presets use the 'systemd' hook (→ sd-plymouth);
    # legacy presets use 'udev' (→ plymouth).
    if _has_package "plymouth"; then
        info "Adding plymouth hook to mkinitcpio..."
        if grep -qE '^HOOKS=.*\bsystemd\b' /etc/mkinitcpio.conf; then
            sed -i '/^HOOKS=/s/\bsystemd\b/systemd sd-plymouth/' /etc/mkinitcpio.conf
        else
            sed -i '/^HOOKS=/s/\budev\b/udev plymouth/' /etc/mkinitcpio.conf
        fi
    fi

    run mkinitcpio -P
    success "Initramfs images created."
}
