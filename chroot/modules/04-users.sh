#!/usr/bin/env bash
# =============================================================================
# Chroot module — Root password and user accounts
# Ref: https://wiki.archlinux.org/title/Installation_guide#Root_password
# =============================================================================

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
_sudoers_wheel="/etc/sudoers.d/wheel"
if [[ ! -f "${_sudoers_wheel}" ]]; then
    echo "%wheel ALL=(ALL:ALL) ALL" > "${_sudoers_wheel}"
    chmod 0440 "${_sudoers_wheel}"
    info "Enabled sudo for wheel group via ${_sudoers_wheel}."
fi

_users_created=0

# Main user — collected interactively before installation; always placed in
# wheel (grants sudo).  Additional groups are added by package hooks when
# the corresponding hardware/service requires it (e.g. docker.sh → docker).
if [[ -n "${INSTALL_USERNAME:-}" ]]; then
    _create_user "${INSTALL_USERNAME}" "wheel" "${INSTALL_USER_PASSWORD:-}"
    _users_created=$((_users_created + 1))
fi

# Additional users from the USERS array (advanced preset configs)
for _user_entry in "${USERS[@]+"${USERS[@]}"}"; do
    [[ -z "${_user_entry}" ]] && continue
    _username="${_user_entry%%:*}"
    _rest="${_user_entry#*:}"
    if [[ "${_rest}" == *:* ]]; then
        _groups="${_rest##*:}"
        _password="${_rest%:*}"
    else
        _password="${_rest}"
        _groups=""
    fi
    _create_user "${_username}" "${_groups}" "${_password}"
    _users_created=$((_users_created + 1))
done

if (( _users_created == 0 )); then
    warn "No users configured."
fi
