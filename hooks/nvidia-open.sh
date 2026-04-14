#!/usr/bin/env bash
# Hook: nvidia-open
# Configures early KMS for the NVIDIA open kernel modules by adding the
# required modules to the mkinitcpio MODULES array and regenerating the
# initramfs.  Early loading ensures the NVIDIA driver is active before the
# display manager (GDM/Wayland) starts.
#
# Ref: https://wiki.archlinux.org/title/NVIDIA#DRM_kernel_mode_setting
# Ref: https://wiki.archlinux.org/title/NVIDIA#Early_loading

set -euo pipefail

_conf=/etc/mkinitcpio.conf

if [[ ! -f "${_conf}" ]]; then
    echo "nvidia-open hook: ${_conf} not found, skipping." >&2
    exit 0
fi

# Add the four NVIDIA kernel modules to the MODULES array if any of them are
# missing.  All four are required for full early-KMS support.
# Ref: https://wiki.archlinux.org/title/NVIDIA#Early_loading
_needs_update=false
for _mod in nvidia nvidia_modeset nvidia_uvm nvidia_drm; do
    if ! grep -qE "^MODULES=.*\b${_mod}\b" "${_conf}"; then
        _needs_update=true
        break
    fi
done

if [[ "${_needs_update}" == true ]]; then
    # Read the existing MODULES list, normalise whitespace, then append any
    # missing nvidia modules one by one to avoid duplicates.
    _current=$(sed -n 's/^MODULES=(\(.*\))/\1/p' "${_conf}" | tr -s ' ' | sed 's/^ //;s/ $//')
    for _mod in nvidia nvidia_modeset nvidia_uvm nvidia_drm; do
        if ! echo " ${_current} " | grep -qw "${_mod}"; then
            _current="${_current:+${_current} }${_mod}"
        fi
    done
    sed -i "s|^MODULES=(.*)|MODULES=(${_current})|" "${_conf}"
    echo "==> nvidia-open: added NVIDIA modules to mkinitcpio MODULES for early loading."
fi
unset _needs_update _current _mod

# Regenerate initramfs so the new MODULES list takes effect.
mkinitcpio -P
