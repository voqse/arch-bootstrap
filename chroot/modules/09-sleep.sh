#!/usr/bin/env bash
# =============================================================================
# Chroot module — Sleep / hibernate configuration
# When HIBERNATE_DELAY is set, configures suspend-then-hibernate so that the
# system automatically hibernates after being suspended for that long.
# =============================================================================

chroot_sleep() {
    if [[ -z "${HIBERNATE_DELAY:-}" ]]; then
        return
    fi

    section "Configuring suspend-then-hibernate (delay: ${HIBERNATE_DELAY})"

    # -- systemd sleep: set HibernateDelaySec --------------------------------
    mkdir -p /etc/systemd/sleep.conf.d
    cat > /etc/systemd/sleep.conf.d/hibernate-delay.conf <<EOF
[Sleep]
HibernateDelaySec=${HIBERNATE_DELAY}
EOF
    success "HibernateDelaySec=${HIBERNATE_DELAY} written to sleep.conf.d."

    # -- logind: battery → suspend-then-hibernate; AC power → screen lock only
    mkdir -p /etc/systemd/logind.conf.d
    cat > /etc/systemd/logind.conf.d/hibernate.conf <<EOF
[Login]
HandleSuspendKey=suspend-then-hibernate
HandleLidSwitch=suspend-then-hibernate
HandleLidSwitchExternalPower=lock
EOF
    success "logind configured: battery=suspend-then-hibernate, AC=lock (screen off)."
}
