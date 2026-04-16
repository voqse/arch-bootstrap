#!/usr/bin/env bash
# =============================================================================
# chroot/configure.sh — Runs inside arch-chroot to configure the new system.
# Ref: https://wiki.archlinux.org/title/Installation_guide#Configure_the_system
# =============================================================================
set -euo pipefail

CHROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${CHROOT_DIR}/lib.sh"
source "${CHROOT_DIR}/config.sh"

# Source each module in sorted order; each module runs as a plain script.
shopt -s nullglob
modules=("${CHROOT_DIR}/modules"/[0-9]*.sh)
shopt -u nullglob
[[ ${#modules[@]} -eq 0 ]] && die "No modules found in ${CHROOT_DIR}/modules/"

for module in "${modules[@]}"; do
    # shellcheck source=/dev/null
    source "${module}"
done
