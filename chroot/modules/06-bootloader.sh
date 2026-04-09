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

    local bootloader_id="${GRUB_BOOTLOADER_ID:-GRUB}"
    local timeout="${GRUB_TIMEOUT:-5}"
    local timeout_style="${GRUB_TIMEOUT_STYLE:-menu}"
    local disable_os_prober="${GRUB_DISABLE_OS_PROBER:-false}"

    # Apply GRUB defaults before generating the config
    local grub_default="/etc/default/grub"
    _grub_set_value "${grub_default}" "GRUB_TIMEOUT"       "${timeout}"
    _grub_set_value "${grub_default}" "GRUB_TIMEOUT_STYLE" "${timeout_style}"
    if [[ "${disable_os_prober}" == "true" ]]; then
        _grub_set_value "${grub_default}" "GRUB_DISABLE_OS_PROBER" "true"
    fi

    info "Installing GRUB for UEFI (bootloader-id: ${bootloader_id})..."
    run grub-install \
        --target=x86_64-efi \
        --efi-directory=/boot/efi \
        "--bootloader-id=${bootloader_id}" \
        "${DISK}"

    info "Generating GRUB configuration..."
    run grub-mkconfig -o /boot/grub/grub.cfg

    success "GRUB installed and configured."
}

# Set or replace a key=value pair in a GRUB defaults file.
_grub_set_value() {
    local file="$1" key="$2" value="$3"
    if grep -q "^${key}=" "${file}" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "${file}"
    elif grep -q "^#${key}=" "${file}" 2>/dev/null; then
        sed -i "s|^#${key}=.*|${key}=${value}|" "${file}"
    else
        echo "${key}=${value}" >> "${file}"
    fi
    info "GRUB: ${key}=${value}"
}
