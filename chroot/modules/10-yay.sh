#!/usr/bin/env bash
# =============================================================================
# Chroot module — yay (AUR helper) initialisation
# Builds and installs yay from the AUR as the primary install user, then
# installs every package listed in YAY_PACKAGES and removes the build tree.
# Ref: https://github.com/Jguer/yay
# =============================================================================

chroot_yay() (
    section "yay AUR helper"

    if [[ ${#YAY_PACKAGES[@]} -eq 0 ]]; then
        info "YAY_PACKAGES is empty — skipping yay setup."
        return
    fi

    require_var INSTALL_USERNAME

    local build_dir="/home/${INSTALL_USERNAME}/yay"
    local sudoers_tmp="/etc/sudoers.d/yay-build"

    # Grant temporary passwordless sudo for pacman (used by makepkg -s and yay)
    echo "${INSTALL_USERNAME} ALL=(ALL) NOPASSWD: /usr/bin/pacman" > "${sudoers_tmp}"
    chmod 0440 "${sudoers_tmp}"
    trap 'rm -f "${sudoers_tmp}"' EXIT INT TERM HUP

    # Clone yay from the AUR
    info "Cloning yay from AUR..."
    run sudo -H -u "${INSTALL_USERNAME}" git clone --depth=1 \
        https://aur.archlinux.org/yay.git "${build_dir}"

    # Build and install yay
    info "Building and installing yay..."
    run sudo -H -u "${INSTALL_USERNAME}" bash -c \
        "cd '${build_dir}' && makepkg -si --noconfirm"

    # Remove the yay repository directory
    info "Removing yay build directory..."
    run rm -rf "${build_dir}"
    success "yay build directory removed."

    success "yay installed."

    # Install AUR packages
    info "Installing AUR packages: ${YAY_PACKAGES[*]}"
    run sudo -H -u "${INSTALL_USERNAME}" \
        yay -S --noconfirm --answerdiff=None --answerclean=None \
        "${YAY_PACKAGES[@]}"

    success "AUR packages installed: ${YAY_PACKAGES[*]}"
)
