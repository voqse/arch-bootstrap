#!/usr/bin/env bash
# =============================================================================
# Chroot module — Network configuration / Hostname
# Ref: https://wiki.archlinux.org/title/Installation_guide#Network_configuration
# =============================================================================

chroot_hostname() {
    section "Hostname"

    require_var HOSTNAME

    echo "${HOSTNAME}" > /etc/hostname
    success "Hostname set to: ${HOSTNAME}."

    # /etc/hosts
    cat > /etc/hosts <<EOF
127.0.0.1   localhost
::1         localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
EOF
    success "/etc/hosts written."
}
