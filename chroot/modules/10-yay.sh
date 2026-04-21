#!/usr/bin/env bash
# Chroot module — yay (AUR helper) initialisation
# Builds and installs yay from the AUR as the primary install user, then
# installs every package listed in YAY_PACKAGES and removes the build tree.
# Ref: https://github.com/Jguer/yay

# Run in a subshell so the EXIT trap and temporary variable assignments are
# isolated from the rest of the chroot configuration.  `exit` (not `return`)
# is used for early exit because this is a bare subshell, not a function.
(
    section "yay AUR helper"

    require_var INSTALL_USERNAME

    _build_dir="/home/${INSTALL_USERNAME}/yay"
    _sudoers_tmp="/etc/sudoers.d/yay-build"

    # Grant the user passwordless pacman access so makepkg and yay never
    # prompt for a password during the unattended build.
    # The entry is temporary — the EXIT trap removes it when this subshell ends.
    printf '%s ALL=(ALL) NOPASSWD: /usr/bin/pacman\n' \
        "${INSTALL_USERNAME}" > "${_sudoers_tmp}"
    chmod 0440 "${_sudoers_tmp}"
    trap 'rm -f "${_sudoers_tmp}"' EXIT INT TERM HUP

    # Remove any leftover build directory to make this step re-runnable.
    rm -rf "${_build_dir}"

    # Clone yay from the AUR
    info "Cloning yay from AUR..."
    run sudo -H -u "${INSTALL_USERNAME}" \
        git clone --depth=1 \
        https://aur.archlinux.org/yay.git "${_build_dir}"

    # Build and install yay; NOPASSWD sudoers covers the internal pacman calls.
    info "Building and installing yay..."
    run sudo -H -u "${INSTALL_USERNAME}" \
        bash -c "cd '${_build_dir}' && makepkg -si --noconfirm"

    # Remove the yay repository directory
    info "Removing yay build directory..."
    run rm -rf "${_build_dir}"
    success "yay build directory removed."

    success "yay installed."

    if [[ ${#YAY_PACKAGES[@]} -gt 0 ]]; then
        # Install AUR packages one by one so a single failure does not abort
        # the entire installation.
        _yay_hooks_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hooks"
        for _pkg in "${YAY_PACKAGES[@]}"; do
            info "Installing AUR package: ${_pkg}"
            if run sudo -H -u "${INSTALL_USERNAME}" \
                yay -S --noconfirm --answerdiff=None --answerclean=None \
                "${_pkg}"; then
                success "AUR package installed: ${_pkg}"
                run_hooks "${_yay_hooks_dir}" "AUR package" "${_pkg}"
            else
                warn "Failed to install AUR package: ${_pkg} — skipping."
            fi
        done
    else
        info "YAY_PACKAGES is empty — skipping AUR package installation."
    fi
)
