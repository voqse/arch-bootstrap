#!/usr/bin/env bash
# Hook: amdgpu
# Configures early KMS for the AMD GPU by adding the amdgpu module to the
# mkinitcpio MODULES array and regenerating the initramfs.
# Early loading ensures the display is active before GDM/Wayland starts.
#
# Ref: https://wiki.archlinux.org/title/AMDGPU#Early_KMS_start

set -euo pipefail

_conf=/etc/mkinitcpio.conf

if [[ ! -f "${_conf}" ]]; then
    echo "amdgpu hook: ${_conf} not found, skipping." >&2
    exit 0
fi

# Extract the existing MODULES value for reliable word-boundary checks.
_current=$(sed -n 's/^MODULES=(\(.*\))/\1/p' "${_conf}" | tr -s ' ' | sed 's/^ //;s/ $//')

if echo " ${_current} " | grep -qw "amdgpu"; then
    echo "==> amdgpu: mkinitcpio MODULES already contains amdgpu; skipping initramfs regeneration."
else
    _current="${_current:+${_current} }amdgpu"
    sed -i -E "s|^MODULES=\(.*\)|MODULES=(${_current})|" "${_conf}"
    echo "==> amdgpu: added amdgpu to mkinitcpio MODULES for early KMS."

    # Regenerate initramfs so the new MODULES list takes effect.
    mkinitcpio -P
fi
unset _current
