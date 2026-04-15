#!/usr/bin/env bash
# =============================================================================
# Module 04 — Package installation via pacstrap
# Installs base packages plus user-defined packages into /mnt.
# Ref: https://wiki.archlinux.org/title/Installation_guide#Install_essential_packages
# =============================================================================

module_pacstrap() {
    section "Package installation (pacstrap)"

    # Write /mnt/etc/vconsole.conf before pacstrap so that the mkinitcpio
    # sd-vconsole hook can find it when the linux package is installed.
    # Without this file the hook emits an error and the initramfs image may
    # be incomplete.  The chroot localization module will overwrite this file
    # later with the same values.
    run mkdir -p /mnt/etc
    {
        echo "KEYMAP=${KEYMAP}"
        echo "FONT=${FONT}"
        [[ -n "${XKBLAYOUT:-}" ]] && echo "XKBLAYOUT=${XKBLAYOUT}"
        [[ -n "${XKBOPTIONS:-}" ]] && echo "XKBOPTIONS=${XKBOPTIONS}"
    } > /mnt/etc/vconsole.conf
    info "Pre-wrote /mnt/etc/vconsole.conf (KEYMAP=${KEYMAP}, FONT=${FONT})."

    # Write /mnt/etc/locale.conf so that perl-based pacman hooks do not emit
    # locale warnings during installation.
    echo "LANG=${LANG}" > /mnt/etc/locale.conf
    info "Pre-wrote /mnt/etc/locale.conf (LANG=${LANG})."

    local all_packages=()

    # Base packages (always installed)
    for entry in "${BASE_PACKAGES[@]}"; do
        all_packages+=("${entry%%:*}")
    done

    # User-defined packages (strip optional hook suffix)
    for entry in "${PACKAGES[@]}"; do
        all_packages+=("${entry%%:*}")
    done

    info "Installing packages: ${all_packages[*]}"
    run pacstrap -K /mnt "${all_packages[@]}"
    success "pacstrap completed."
}
