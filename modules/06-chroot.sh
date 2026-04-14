#!/usr/bin/env bash
# =============================================================================
# Module 06 — Chroot configuration
# Copies required files into /mnt and runs the chroot configurator.
# Ref: https://wiki.archlinux.org/title/Installation_guide#Chroot
# =============================================================================

module_chroot() {
    section "Chroot configuration"

    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

    # Copy chroot scripts and hooks into the new system
    info "Copying chroot scripts into /mnt..."
    cp -r "${script_dir}/chroot"  /mnt/root/arch-bootstrap-chroot
    cp -r "${script_dir}/hooks"   /mnt/root/arch-bootstrap-chroot/hooks
    cp    "${script_dir}/lib.sh"  /mnt/root/arch-bootstrap-chroot/lib.sh

    # Write the resolved config so the chroot environment reads the same values
    _export_config > /mnt/root/arch-bootstrap-chroot/config.sh

    chmod +x /mnt/root/arch-bootstrap-chroot/configure.sh

    info "Entering chroot..."
    run arch-chroot /mnt /root/arch-bootstrap-chroot/configure.sh

    # Cleanup
    rm -rf /mnt/root/arch-bootstrap-chroot
    success "Chroot configuration complete."
}

# Serialise all config variables into a sourceable shell file.
_export_config() {
    cat <<EOF
#!/usr/bin/env bash
# Auto-generated config — do not edit manually.
LOCALES=($(printf '"%s" ' "${LOCALES[@]+"${LOCALES[@]}"}"))
LANG="${LANG}"
KEYMAP="${KEYMAP}"
FONT="${FONT}"
TIMEZONE="${TIMEZONE}"
NTP_ENABLED="${NTP_ENABLED:-true}"
HOSTNAME="${HOSTNAME}"
INSTALL_USERNAME="${INSTALL_USERNAME:-}"
INSTALL_USER_GROUPS="${INSTALL_USER_GROUPS:-}"
INSTALL_USER_PASSWORD="${INSTALL_USER_PASSWORD:-}"
ROOT_PASSWORD="${ROOT_PASSWORD:-}"
USERS=($(printf '"%s" ' "${USERS[@]+"${USERS[@]}"}"))
BOOTLOADER="${BOOTLOADER:-systemd-boot}"
EFI_MOUNTPOINT="${EFI_MOUNTPOINT:-/boot}"
GRUB_BOOTLOADER_ID="${GRUB_BOOTLOADER_ID:-Linux Boot Manager}"
GRUB_TIMEOUT="${GRUB_TIMEOUT:-0}"
GRUB_TIMEOUT_STYLE="${GRUB_TIMEOUT_STYLE:-hidden}"
GRUB_DISABLE_OS_PROBER="${GRUB_DISABLE_OS_PROBER:-true}"
PACKAGES=($(printf '"%s" ' "${PACKAGES[@]+"${PACKAGES[@]}"}"))
SERVICES=($(printf '"%s" ' "${SERVICES[@]+"${SERVICES[@]}"}"))
EFI_PART="${EFI_PART:-}"
ROOT_PART="${ROOT_PART:-}"
SWAP_TYPE="${SWAP_TYPE:-file}"
SWAP_PART="${SWAP_PART:-}"
SWAP_FILE="${SWAP_FILE:-}"
DISK="${DISK:-}"
EOF
}
