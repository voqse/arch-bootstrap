#!/usr/bin/env bash
# =============================================================================
# Chroot module — Initramfs
# mkinitcpio is already run by the linux package post-install, but we
# re-run it here to ensure a clean image with the current configuration.
# Ref: https://wiki.archlinux.org/title/Installation_guide#Initramfs
# =============================================================================

chroot_initramfs() {
    section "Initramfs"

    # Insert the 'plymouth' hook into the HOOKS array.
    # The hook name is always 'plymouth' regardless of the initramfs type.
    # Placement requirement from the Arch Wiki:
    #   - If the 'systemd' hook is present it must appear before 'plymouth'.
    #   - If the legacy 'udev' hook is present, insert after it.
    # Default Arch mkinitcpio.conf uses the systemd-based initramfs.
    # Ref: https://wiki.archlinux.org/title/Plymouth#mkinitcpio
    if _has_package "plymouth"; then
        if _hooks_contain systemd; then
            info "Adding plymouth hook after 'systemd'..."
            sed -i '/^HOOKS=/{ /\<plymouth\>/! s/\<systemd\>/systemd plymouth/; }' /etc/mkinitcpio.conf
        elif _hooks_contain udev; then
            info "Adding plymouth hook after 'udev'..."
            sed -i '/^HOOKS=/{ /\<plymouth\>/! s/\<udev\>/udev plymouth/; }' /etc/mkinitcpio.conf
        else
            warn "Neither 'systemd' nor 'udev' hook found in mkinitcpio HOOKS; skipping plymouth insertion."
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
