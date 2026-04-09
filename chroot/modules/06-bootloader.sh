#!/usr/bin/env bash
# =============================================================================
# Chroot module — Boot loader (GRUB)
# Ref: https://wiki.archlinux.org/title/Installation_guide#Boot_loader
# =============================================================================

chroot_bootloader() {
    section "Boot loader"

    case "${BOOTLOADER:-grub}" in
        grub) _install_grub ;;
        *)    die "Unsupported bootloader: ${BOOTLOADER}. Only 'grub' is currently supported." ;;
    esac
}

_install_grub() {
    require_var DISK

    info "Installing GRUB for UEFI..."
    run grub-install \
        --target=x86_64-efi \
        --efi-directory=/boot/efi \
        --bootloader-id=GRUB \
        "${DISK}"

    info "Generating GRUB configuration..."
    run grub-mkconfig -o /boot/grub/grub.cfg

    success "GRUB installed and configured."
}
