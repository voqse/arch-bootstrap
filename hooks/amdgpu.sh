#!/usr/bin/env bash
# Hook: amdgpu
# Configures early KMS for the AMD GPU by adding the amdgpu module to the
# mkinitcpio MODULES array.  Early loading ensures the display is active
# before GDM/Wayland starts.
#
# Ref: https://wiki.archlinux.org/title/AMDGPU#Early_KMS_start

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${HOOK_DIR}/../lib.sh"

mkinitcpio_add_modules amdgpu
