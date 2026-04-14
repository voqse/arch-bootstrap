#!/usr/bin/env bash
# =============================================================================
# Chroot module — Initramfs
# mkinitcpio is already run by the linux package post-install, but we
# re-run it here to ensure a clean image with the current configuration.
# Ref: https://wiki.archlinux.org/title/Installation_guide#Initramfs
# =============================================================================

chroot_initramfs() {
    section "Initramfs"

    # Insert the 'plymouth' hook after the 'systemd' hook when plymouth is installed.
    # The hook must be placed after 'systemd' per the wiki recommendation.
    # Ref: https://wiki.archlinux.org/title/Plymouth#mkinitcpio
    if _has_package "plymouth"; then
        info "Adding plymouth hook to mkinitcpio..."
        sed -i '/^HOOKS=/{ /\<plymouth\>/! s/\<systemd\>/systemd plymouth/; }' /etc/mkinitcpio.conf
    fi

    run mkinitcpio -P
    success "Initramfs images created."
}
