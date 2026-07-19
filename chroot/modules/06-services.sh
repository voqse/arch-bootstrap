#!/usr/bin/env bash
# Chroot module — Systemd service enablement
# Enables every service listed in the SERVICES config array.
# Intended for services not tied to a specific package (e.g. built-in systemd
# timers like fstrim.timer). Package-specific services are enabled in hooks.

section "Enabling services"

# Monthly scrub of / — the only btrfs maintenance worth automating (balance
# and defrag timers cause more trouble than they solve on modern btrfs).
# "-" is the systemd path escape for "/". Conditional on the filesystem, so
# it lives here rather than in the unconditional SERVICES array.
# Ref: https://wiki.archlinux.org/title/Btrfs#Scrub
if [[ "${FILESYSTEM:-btrfs}" == "btrfs" ]]; then
    info "Enabling: btrfs-scrub@-.timer (monthly scrub of /)"
    systemctl enable btrfs-scrub@-.timer || warn "Failed to enable btrfs-scrub@-.timer."
fi

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
