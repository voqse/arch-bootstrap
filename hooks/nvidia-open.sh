#!/usr/bin/env bash
# Hook: nvidia-open
# Configures early KMS for the NVIDIA open kernel modules by adding the
# required modules to the mkinitcpio MODULES array.  Early loading ensures
# the NVIDIA driver is active before the display manager (GDM/Wayland) starts.
#
# Ref: https://wiki.archlinux.org/title/NVIDIA#DRM_kernel_mode_setting
# Ref: https://wiki.archlinux.org/title/NVIDIA#Early_loading

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${HOOK_DIR}/../lib.sh"

mkinitcpio_add_modules nvidia nvidia_modeset nvidia_uvm nvidia_drm
