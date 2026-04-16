#!/usr/bin/env bash
# =============================================================================
# Chroot module — Root password and user accounts
# Ref: https://wiki.archlinux.org/title/Installation_guide#Root_password
# =============================================================================

chroot_users() {
    section "Root password"

    if [[ -z "${ROOT_PASSWORD:-}" ]]; then
        warn "ROOT_PASSWORD is empty — root account will be locked."
        run passwd -l root
    else
        echo "root:${ROOT_PASSWORD}" | chpasswd
        success "Root password set."
    fi

    section "User accounts"

    # Ensure wheel group members can use sudo
    local sudoers_wheel="/etc/sudoers.d/wheel"
    if [[ ! -f "${sudoers_wheel}" ]]; then
        echo "%wheel ALL=(ALL:ALL) ALL" > "${sudoers_wheel}"
        chmod 0440 "${sudoers_wheel}"
        info "Enabled sudo for wheel group via ${sudoers_wheel}."
    fi

    local created=0

    # Main user — collected interactively before installation; always placed in
    # wheel (grants sudo).  Additional groups are added by package hooks when
    # the corresponding hardware/service requires it (e.g. docker.sh → docker).
    if [[ -n "${INSTALL_USERNAME:-}" ]]; then
        _create_user "${INSTALL_USERNAME}" "wheel" "${INSTALL_USER_PASSWORD:-}"
        created=$((created + 1))
    fi

    # Additional users from the USERS array (advanced preset configs)
    for entry in "${USERS[@]+"${USERS[@]}"}"; do
        [[ -z "${entry}" ]] && continue
        local username password groups
        username="${entry%%:*}"
        local rest="${entry#*:}"
        if [[ "${rest}" == *:* ]]; then
            groups="${rest##*:}"
            password="${rest%:*}"
        else
            password="${rest}"
            groups=""
        fi
        _create_user "${username}" "${groups}" "${password}"
        created=$((created + 1))
    done

    if (( created == 0 )); then
        warn "No users configured."
    fi
}

_create_user() {
    local username="$1" groups="$2" password="$3"

    info "Creating user: ${username}"

    local useradd_args=(-m -s /bin/bash)
    [[ -n "${groups}" ]] && useradd_args+=(-G "${groups}")

    if id "${username}" &>/dev/null; then
        warn "User '${username}' already exists; skipping creation."
    else
        run useradd "${useradd_args[@]}" "${username}"
    fi

    if [[ -z "${password}" ]]; then
        warn "No password for '${username}' — account locked."
        passwd -l "${username}" || true
    else
        echo "${username}:${password}" | chpasswd
        success "Password set for ${username}."
    fi
}
