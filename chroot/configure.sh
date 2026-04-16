#!/usr/bin/env bash
# =============================================================================
# chroot/configure.sh — Runs inside arch-chroot to configure the new system.
# Ref: https://wiki.archlinux.org/title/Installation_guide#Configure_the_system
# =============================================================================
set -euo pipefail

CHROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${CHROOT_DIR}/lib.sh"
source "${CHROOT_DIR}/config.sh"

# Source each module and invoke its entry-point function automatically.
# Convention: the function name is derived from the filename by stripping the
# leading numeric prefix and replacing hyphens with underscores, then
# prefixing with "chroot_".  E.g. "03-hostname.sh" → "chroot_hostname".
for module in "${CHROOT_DIR}/modules"/[0-9]*.sh; do
    # shellcheck source=/dev/null
    source "${module}"
    func="chroot_$(basename "${module}" .sh | sed 's/^[0-9]*-//' | tr '-' '_')"
    "${func}"
done
