#!/usr/bin/env bash
# =============================================================================
# Chroot module — Root password and user accounts
# Ref: https://wiki.archlinux.org/title/Installation_guide#Root_password
# =============================================================================

chroot_root_password() {
    section "Root password"

    if [[ -z "${ROOT_PASSWORD:-}" ]]; then
        warn "ROOT_PASSWORD is empty — root account will be locked."
        run passwd -l root
    else
        echo "root:${ROOT_PASSWORD}" | chpasswd
        success "Root password set."
    fi
}

chroot_users() {
    section "User accounts"

    if [[ ${#USERS[@]} -eq 0 ]]; then
        info "No users defined in config; skipping."
        return
    fi

    # Ensure sudo is configured so wheel members have sudo access
    local sudoers_wheel="/etc/sudoers.d/wheel"
    if [[ ! -f "${sudoers_wheel}" ]]; then
        echo "%wheel ALL=(ALL:ALL) ALL" > "${sudoers_wheel}"
        chmod 0440 "${sudoers_wheel}"
        info "Enabled sudo for wheel group via ${sudoers_wheel}."
    fi

    for entry in "${USERS[@]}"; do
        local username password groups
        IFS=':' read -r username password groups <<< "${entry}"

        if [[ -z "${username}" ]]; then
            warn "Skipping empty user entry."
            continue
        fi

        info "Creating user: ${username}"

        local useradd_args=(-m -s /bin/bash)
        if [[ -n "${groups}" ]]; then
            useradd_args+=(-G "${groups}")
        fi

        if id "${username}" &>/dev/null; then
            warn "User '${username}' already exists; skipping creation."
        else
            run useradd "${useradd_args[@]}" "${username}"
        fi

        if [[ -z "${password}" ]]; then
            warn "No password for '${username}' — account locked. Set it manually after reboot."
            passwd -l "${username}" || true
        elif [[ "${password}" == "?" ]]; then
            info "Enter password for '${username}':"
            until passwd "${username}"; do
                warn "Password mismatch or error, please try again."
            done
            success "Password set for ${username}."
        else
            echo "${username}:${password}" | chpasswd
            success "Password set for ${username}."
        fi
    done
}
