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
    # Placement requirements from the Arch Wiki:
    #   - 'plymouth' must come after 'kms' so that KMS (GPU driver) is
    #     initialised before Plymouth tries to open a framebuffer. Without
    #     this, Plymouth falls back to text-mode on AMD/Intel integrated
    #     graphics and the graphical spinner never appears.
    #   - If the 'systemd' hook is present it must appear before 'plymouth'.
    #   - If the legacy 'udev' hook is present, insert after it.
    # Default Arch mkinitcpio.conf uses the systemd-based initramfs with kms:
    #   HOOKS=(base systemd autodetect microcode modconf kms keyboard
    #          sd-vconsole block filesystems fsck)
    # Ref: https://wiki.archlinux.org/title/Plymouth#mkinitcpio
    if _has_package "plymouth"; then
        if _hooks_contain kms; then
            info "Adding plymouth hook after 'kms'..."
            sed -i '/^HOOKS=/{ /\<plymouth\>/! s/\<kms\>/kms plymouth/; }' /etc/mkinitcpio.conf
        elif _hooks_contain systemd; then
            info "Adding plymouth hook after 'systemd'..."
            sed -i '/^HOOKS=/{ /\<plymouth\>/! s/\<systemd\>/systemd plymouth/; }' /etc/mkinitcpio.conf
        elif _hooks_contain udev; then
            info "Adding plymouth hook after 'udev'..."
            sed -i '/^HOOKS=/{ /\<plymouth\>/! s/\<udev\>/udev plymouth/; }' /etc/mkinitcpio.conf
        else
            warn "Neither 'kms', 'systemd', nor 'udev' hook found in mkinitcpio HOOKS; skipping plymouth insertion."
        fi
    fi

    run mkinitcpio -P
    success "Initramfs images created."
}

# Return 0 if the specified hook appears in the HOOKS=(...) line of mkinitcpio.conf.
_hooks_contain() {
    local hook="$1"
    grep -qE "^HOOKS=\([^)]*([[:space:]]|\()${hook}([[:space:]]|\))[^)]*\)" /etc/mkinitcpio.conf 2>/dev/null
}
