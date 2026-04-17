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

    if [[ ${#YAY_PACKAGES[@]} -eq 0 ]]; then
        info "YAY_PACKAGES is empty — skipping yay setup."
        exit 0
    fi

    require_var INSTALL_USERNAME
    require_var INSTALL_USER_PASSWORD

    _build_dir="/home/${INSTALL_USERNAME}/yay"
    _sudoers_tmp="/etc/sudoers.d/yay-build"

    # Provide the user's password to sudo non-interactively via SUDO_ASKPASS,
    # so makepkg / yay can call 'sudo pacman' without a manual prompt.
    # Use /dev/shm (tmpfs) so the files never touch disk.
    _passfile=$(mktemp /dev/shm/yay-pass.XXXXXX)
    _askpass=$(mktemp /dev/shm/yay-askpass.XXXXXX)
    printf '%s\n' "${INSTALL_USER_PASSWORD}" > "${_passfile}"
    chmod 0600 "${_passfile}"
    chown "${INSTALL_USERNAME}": "${_passfile}"
    printf '#!/bin/sh\ncat "%s"\n' "${_passfile}" > "${_askpass}"
    chmod 0700 "${_askpass}"
    chown "${INSTALL_USERNAME}": "${_askpass}"

    # Sudoers entry: allow the user to run pacman and preserve SUDO_ASKPASS
    # across the sudo boundary (no NOPASSWD — password is supplied via askpass).
    cat > "${_sudoers_tmp}" <<EOF
Defaults:${INSTALL_USERNAME} env_keep += "SUDO_ASKPASS"
${INSTALL_USERNAME} ALL=(ALL) /usr/bin/pacman
EOF
    chmod 0440 "${_sudoers_tmp}"
    trap 'rm -f "${_sudoers_tmp}" "${_passfile}" "${_askpass}"' EXIT INT TERM HUP

    # Remove any leftover build directory to make this step re-runnable.
    rm -rf "${_build_dir}"

    # Clone yay from the AUR
    info "Cloning yay from AUR..."
    run sudo -H -u "${INSTALL_USERNAME}" \
        git clone --depth=1 \
        https://aur.archlinux.org/yay.git "${_build_dir}"

    # Build and install yay; SUDO_ASKPASS supplies the password to internal pacman calls.
    info "Building and installing yay..."
    run sudo -H -u "${INSTALL_USERNAME}" \
        env SUDO_ASKPASS="${_askpass}" \
        bash -c "cd '${_build_dir}' && makepkg -si --noconfirm"

    # Remove the yay repository directory
    info "Removing yay build directory..."
    run rm -rf "${_build_dir}"
    success "yay build directory removed."

    success "yay installed."

    # Install AUR packages
    info "Installing AUR packages: ${YAY_PACKAGES[*]}"
    run sudo -H -u "${INSTALL_USERNAME}" \
        env SUDO_ASKPASS="${_askpass}" \
        yay -S --noconfirm --answerdiff=None --answerclean=None \
        "${YAY_PACKAGES[@]}"

    success "AUR packages installed: ${YAY_PACKAGES[*]}"
)
