#!/usr/bin/env bash
# =============================================================================
# chroot/configure.sh — Runs inside arch-chroot to configure the new system.
# Ref: https://wiki.archlinux.org/title/Installation_guide#Configure_the_system
# =============================================================================
set -euo pipefail

CHROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${CHROOT_DIR}/lib.sh"
source "${CHROOT_DIR}/config.sh"

for module in "${CHROOT_DIR}/modules"/[0-9]*.sh; do
    # shellcheck source=/dev/null
    source "${module}"
done

chroot_timezone
chroot_localization
chroot_hostname
chroot_network
chroot_root_password
chroot_users
chroot_bootloader
chroot_services
chroot_package_hooks
chroot_sleep
chroot_initramfs
chroot_yay
