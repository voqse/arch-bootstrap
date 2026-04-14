#!/usr/bin/env bash
# =============================================================================
# Chroot module — Initramfs
# mkinitcpio is already run by the linux package post-install, but we
# re-run it here to ensure a clean image with the current configuration.
# Ref: https://wiki.archlinux.org/title/Installation_guide#Initramfs
# =============================================================================

chroot_initramfs() {
    section "Initramfs"

    # Insert the plymouth hook after udev when plymouth is installed
    if _has_package "plymouth"; then
        info "Adding plymouth hook to mkinitcpio..."
        sed -i '/^HOOKS=/s/\budev\b/udev plymouth/' /etc/mkinitcpio.conf
    fi

    run mkinitcpio -P
    success "Initramfs images created."
}
