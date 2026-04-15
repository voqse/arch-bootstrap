#!/usr/bin/env bash
# =============================================================================
# Chroot module — Initramfs
# Runs after all package hooks so that any mkinitcpio.conf modifications
# (e.g. amdgpu/nvidia early-KMS modules, plymouth splash hook) are applied
# in a single regeneration pass.
# Ref: https://wiki.archlinux.org/title/Installation_guide#Initramfs
# =============================================================================

chroot_initramfs() {
    section "Initramfs"

    run mkinitcpio -P
    success "Initramfs images created."
}
