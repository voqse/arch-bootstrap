#!/usr/bin/env bash
# =============================================================================
# Chroot module — Initramfs
# mkinitcpio is already run by the linux package post-install, but we
# re-run it here to ensure a clean image with the current configuration.
# Ref: https://wiki.archlinux.org/title/Installation_guide#Initramfs
# =============================================================================

chroot_initramfs() {
    section "Initramfs"

    # Insert the correct Plymouth hook depending on the initramfs type:
    # - systemd-based initramfs: sd-plymouth must come after the 'systemd' hook.
    # - busybox/udev-based initramfs (Arch default): plymouth must come after 'udev'.
    # Ref: https://wiki.archlinux.org/title/Plymouth#mkinitcpio
    if _has_package "plymouth"; then
        if _hooks_contain systemd; then
            info "Adding sd-plymouth hook after 'systemd' (systemd-based initramfs)..."
            sed -i '/^HOOKS=/{ /\<sd-plymouth\>/! s/\<systemd\>/systemd sd-plymouth/; }' /etc/mkinitcpio.conf
        else
            info "Adding plymouth hook after 'udev' (udev-based initramfs)..."
            sed -i '/^HOOKS=/{ /\<plymouth\>/! s/\<udev\>/udev plymouth/; }' /etc/mkinitcpio.conf
        fi
    fi

    run mkinitcpio -P
    success "Initramfs images created."
}

# Return 0 if the specified hook appears in the HOOKS=(...) line of mkinitcpio.conf.
_hooks_contain() {
    local hook="$1"
    grep -qE "^HOOKS=\([^)]*\b${hook}\b[^)]*\)" /etc/mkinitcpio.conf 2>/dev/null
}
