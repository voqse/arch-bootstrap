#!/usr/bin/env bash
# Chroot module — Systemd service enablement
# Enables every service listed in the SERVICES config array.
# Intended for services not tied to a specific package (e.g. built-in systemd
# timers like fstrim.timer). Package-specific services are enabled in hooks.

section "Enabling services"

if [[ ${#SERVICES[@]} -eq 0 ]]; then
    info "No services defined in SERVICES; skipping."
    return
fi

_services_enabled=0
for _svc in "${SERVICES[@]}"; do
    info "Enabling: ${_svc}"
    systemctl enable "${_svc}" || warn "Failed to enable ${_svc}."
    _services_enabled=$((_services_enabled + 1))
done

success "Enabled ${_services_enabled} service(s)."
