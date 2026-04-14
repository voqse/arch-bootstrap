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

# Add the four NVIDIA kernel modules to the MODULES array if not already
# present.  All four are required for full early-KMS support.
if ! grep -qE '^MODULES=.*\bnvidia\b' "${_conf}"; then
    # Handle both empty MODULES=() and MODULES=(existing modules)
    sed -i 's/^MODULES=(\(.*\))/MODULES=(\1 nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' "${_conf}"
    # Normalise any leading space that appears when MODULES was previously empty
    sed -i 's/^MODULES=( /MODULES=(/' "${_conf}"
    echo "==> nvidia-open: added NVIDIA modules to mkinitcpio MODULES for early loading."
fi

# Regenerate initramfs so the new MODULES list takes effect.
mkinitcpio -P
