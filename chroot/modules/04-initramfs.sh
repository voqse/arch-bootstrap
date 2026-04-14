#!/usr/bin/env bash
# =============================================================================
# Chroot module — Initramfs
# mkinitcpio is already run by the linux package post-install, but we
# re-run it here to ensure a clean image with the current configuration.
# Ref: https://wiki.archlinux.org/title/Installation_guide#Initramfs
# =============================================================================

chroot_initramfs() {
    section "Initramfs"

    # Insert the 'plymouth' hook when plymouth is installed.
    # The hook name is always 'plymouth' regardless of whether 'systemd' or
    # 'udev' is used. When 'systemd' is present it must precede 'plymouth';
    # when only 'udev' is present, we insert after 'udev'.
    # Ref: https://wiki.archlinux.org/title/Plymouth#mkinitcpio
    if _has_package "plymouth"; then
        info "Adding plymouth hook to mkinitcpio..."
        if grep -qE '^HOOKS=.*\bsystemd\b' /etc/mkinitcpio.conf; then
            sed -i '/^HOOKS=/s/\bsystemd\b/systemd plymouth/' /etc/mkinitcpio.conf
        else
            sed -i '/^HOOKS=/s/\budev\b/udev plymouth/' /etc/mkinitcpio.conf
        fi
    fi

    run mkinitcpio -P
    success "Initramfs images created."
}
