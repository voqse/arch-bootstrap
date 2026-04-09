#!/usr/bin/env bash
# =============================================================================
# Chroot module — Time zone
# Ref: https://wiki.archlinux.org/title/Installation_guide#Time_zone
# =============================================================================

chroot_timezone() {
    section "Time zone"

    require_var TIMEZONE

    run ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
    run hwclock --systohc
    success "Timezone set to ${TIMEZONE}."

    if [[ "${NTP_ENABLED:-true}" == "true" ]]; then
        run systemctl enable systemd-timesyncd.service
        success "NTP time synchronisation enabled (systemd-timesyncd)."
    fi
}
