#!/usr/bin/env bash
# =============================================================================
# Module 04 — Package installation via pacstrap
# Installs base packages plus user-defined packages into /mnt.
# Ref: https://wiki.archlinux.org/title/Installation_guide#Install_essential_packages
# =============================================================================

module_pacstrap() {
    section "Package installation (pacstrap)"

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
