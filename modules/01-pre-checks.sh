#!/usr/bin/env bash
# =============================================================================
# Module 01 — Pre-installation checks
# Verifies UEFI boot mode and internet connectivity, updates the system clock.
# Ref: https://wiki.archlinux.org/title/Installation_guide#Pre-installation
# =============================================================================

section "Pre-installation checks"

# --- UEFI mode ---
if [[ -d /sys/firmware/efi/efivars ]]; then
    success "UEFI boot mode detected."
else
    die "UEFI boot mode not detected. This script requires UEFI."
fi

# --- Internet connectivity ---
info "Checking internet connectivity..."
if ping -c 1 -W 5 archlinux.org &>/dev/null; then
    success "Internet connection is available."
else
    die "No internet connection. Please connect and retry."
fi

# --- System clock ---
info "Enabling NTP and syncing system clock..."
run timedatectl set-ntp true
sleep 2
_ntp_status=$(timedatectl show -p NTPSynchronized --value 2>/dev/null || echo "unknown")
if [[ "$_ntp_status" == "yes" ]]; then
    success "Clock synchronised via NTP."
else
    warn "NTP sync status: ${_ntp_status}. Continuing anyway."
fi

info "Current system time: $(date)"
