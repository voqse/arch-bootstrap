#!/usr/bin/env bash
# Chroot module — Sleep / hibernate configuration
# When HIBERNATE_DELAY is set, configures suspend-then-hibernate so that the
# system automatically hibernates after being suspended for that long.
#
# Requires both:
#   - swap (SWAP_TYPE != none) — the hibernate target to write memory to
#   - power-profiles-daemon in PACKAGES — indicates a battery-powered laptop

if [[ -z "${HIBERNATE_DELAY:-}" ]]; then
    return
fi

if [[ "${SWAP_TYPE:-file}" == "none" ]]; then
    warn "HIBERNATE_DELAY is set but SWAP_TYPE=none — skipping hibernate configuration (no swap to hibernate to)."
    return
fi

if ! _has_package power-profiles-daemon; then
    warn "HIBERNATE_DELAY is set but power-profiles-daemon is not in PACKAGES — skipping hibernate configuration."
    return
fi

section "Configuring suspend-then-hibernate (delay: ${HIBERNATE_DELAY})"

# systemd sleep: set HibernateDelaySec
mkdir -p /etc/systemd/sleep.conf.d
cat > /etc/systemd/sleep.conf.d/hibernate-delay.conf <<EOF
[Sleep]
HibernateDelaySec=${HIBERNATE_DELAY}
EOF
success "HibernateDelaySec=${HIBERNATE_DELAY} written to sleep.conf.d."

# mkinitcpio: add resume hook so the kernel can resume from hibernation
# With a systemd-based initramfs (systemd hook present) the resume mechanism
# is already built-in and no extra hook is needed.
# With a busybox-based initramfs the 'resume' hook must be added before
# 'filesystems'.
# Ref: https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate#Configure_the_initramfs
if mkinitcpio_has_hook systemd; then
    info "mkinitcpio: systemd-based initramfs — built-in resume, no extra hook needed."
elif mkinitcpio_has_hook resume; then
    info "mkinitcpio: 'resume' hook already present."
else
    if ! mkinitcpio_add_hook_before resume filesystems; then
        warn "mkinitcpio: failed to add 'resume' hook before 'filesystems'; skipping hibernate configuration."
        rm -f /etc/systemd/sleep.conf.d/hibernate-delay.conf
        return 0
    fi
fi

# When GNOME is in use, its idle manager calls systemctl suspend via D-Bus,
# bypassing logind's HandleSuspendKey/HandleLidSwitch.  Symlinking
# systemd-suspend.service to systemd-suspend-then-hibernate.service makes
# every low-level suspend request trigger suspend-then-hibernate instead.
# Ref: https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate#Suspend_then_hibernate
if _has_package gnome-shell; then
    mkdir -p /etc/systemd/system
    ln -sf /usr/lib/systemd/system/systemd-suspend-then-hibernate.service \
        /etc/systemd/system/systemd-suspend.service
    success "Symlinked systemd-suspend.service → systemd-suspend-then-hibernate.service for GNOME."
fi

# logind: lid-close on battery → suspend-then-hibernate; lid-close on AC → lock only
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/hibernate.conf <<EOF
[Login]
HandleSuspendKey=suspend-then-hibernate
HandleLidSwitch=suspend-then-hibernate
HandleLidSwitchExternalPower=lock
EOF
success "logind configured: lid-close on battery=suspend-then-hibernate, lid-close on AC=lock."

# GNOME dconf power settings — only when GNOME is installed.
# Battery: blank screen at 5 min, sleep at 15 min; AC: blank screen at 5 min, no sleep.
# Dimming before blank is disabled so the screen switches off cleanly.
# Ref: https://wiki.archlinux.org/title/GNOME/Tips_and_tricks#Power_management
if _has_package gnome-shell; then
    mkdir -p /etc/dconf/db/local.d
    cat > /etc/dconf/db/local.d/03-power <<'EOF'
[org/gnome/desktop/session]
# Blank screen after 5 minutes (300 s) of inactivity
idle-delay=uint32 300

[org/gnome/settings-daemon/plugins/power]
# Do not dim the screen before blanking
idle-dim=false
# Battery: suspend after 15 minutes (900 s) of inactivity.
# Note: this is the idle-to-sleep delay, independent of HibernateDelaySec
# (the sleep-to-hibernate delay set in sleep.conf.d/hibernate-delay.conf).
sleep-inactive-battery-timeout=900
sleep-inactive-battery-type='suspend'
# AC: never auto-suspend
sleep-inactive-ac-timeout=0
sleep-inactive-ac-type='nothing'
EOF
    dconf update
    success "GNOME power settings written to /etc/dconf/db/local.d/03-power."
fi
