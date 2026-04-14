#!/usr/bin/env bash
# =============================================================================
# Chroot module — Systemd service enablement
# Enables every service listed in the SERVICES config array.
# =============================================================================

chroot_services() {
    section "Enabling services"

    if [[ ${#SERVICES[@]} -eq 0 ]]; then
        info "No services defined in SERVICES; skipping."
        return
    fi

    local enabled=0
    for svc in "${SERVICES[@]}"; do
        info "Enabling: ${svc}"
        systemctl enable "${svc}" || warn "Failed to enable ${svc}."
        enabled=$((enabled + 1))
    done

    success "Enabled ${enabled} service(s)."
}
