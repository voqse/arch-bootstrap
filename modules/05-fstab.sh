#!/usr/bin/env bash
# =============================================================================
# Module 05 — Fstab generation
# Ref: https://wiki.archlinux.org/title/Installation_guide#Fstab
# =============================================================================

module_fstab() {
    section "Generating fstab"

    genfstab -U /mnt > /mnt/etc/fstab
    info "Generated fstab:"
    cat /mnt/etc/fstab
    success "fstab written to /mnt/etc/fstab."
}
