#!/usr/bin/env bash
# =============================================================================
# Module 04 — Package installation via pacstrap
# Installs base packages plus user-defined packages into /mnt.
# Ref: https://wiki.archlinux.org/title/Installation_guide#Install_essential_packages
# =============================================================================

# Write vconsole.conf to the given target root before pacstrap so that the
# mkinitcpio sd-vconsole hook can find the file when the linux package is installed.
_write_vconsole_conf() {
    local target_root="$1"

    run mkdir -p "${target_root}/etc"
    {
        echo "KEYMAP=${KEYMAP}"
        echo "FONT=${FONT}"
        [[ -n "${XKBLAYOUT:-}" ]] && echo "XKBLAYOUT=${XKBLAYOUT}"
        [[ -n "${XKBOPTIONS:-}" ]] && echo "XKBOPTIONS=${XKBOPTIONS}"
    } > "${target_root}/etc/vconsole.conf"
}

module_pacstrap() {
    section "Package installation (pacstrap)"

    # Write /mnt/etc/vconsole.conf before pacstrap so that the mkinitcpio
    # sd-vconsole hook can find it when the linux package is installed.
    # Without this file the hook emits an error and the initramfs image may
    # be incomplete.
    _write_vconsole_conf /mnt
    info "Pre-wrote /mnt/etc/vconsole.conf (KEYMAP=${KEYMAP}, FONT=${FONT})."

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
    # Use a safe locale to suppress Perl locale warnings emitted by some pacman
    # scriptlets; locale.conf on the host does not affect the pacstrap env.
    run env LANG=C LC_ALL=C pacstrap -K /mnt "${all_packages[@]}"
    success "pacstrap completed."
}
