#!/usr/bin/env bash
# Hook: plymouth
# Inserts the 'plymouth' hook into mkinitcpio HOOKS and regenerates the
# initramfs so that the Plymouth splash screen is shown on early boot.
#
# Placement rules (Arch Wiki):
#   - 'plymouth' must come after 'kms' so that KMS is initialised before
#     Plymouth tries to open a framebuffer.
#   - If the 'systemd' hook is present it must appear before 'plymouth'
#     (placing after 'kms' already satisfies this for the default HOOKS).
#   - Fallback: place after 'systemd' (no kms), then after 'udev'.
#
# Ref: https://wiki.archlinux.org/title/Plymouth#mkinitcpio

set -euo pipefail

_conf=/etc/mkinitcpio.conf

if [[ ! -f "${_conf}" ]]; then
    echo "plymouth hook: ${_conf} not found, skipping." >&2
    exit 0
fi

# Return 0 if HOOKS=(...) in mkinitcpio.conf contains the given hook name.
_hooks_contain() {
    grep -qE "^HOOKS=\([^)]*([[:space:]]|\()${1}([[:space:]]|\))[^)]*\)" "${_conf}" 2>/dev/null
}

if _hooks_contain plymouth; then
    echo "==> plymouth: mkinitcpio HOOKS already contains plymouth; skipping initramfs regeneration."
    exit 0
fi

if _hooks_contain kms; then
    echo "==> plymouth: adding plymouth hook after 'kms'..."
    sed -i '/^HOOKS=/s/\bkms\b/kms plymouth/' "${_conf}"
elif _hooks_contain systemd; then
    echo "==> plymouth: adding plymouth hook after 'systemd'..."
    sed -i '/^HOOKS=/s/\bsystemd\b/systemd plymouth/' "${_conf}"
elif _hooks_contain udev; then
    echo "==> plymouth: adding plymouth hook after 'udev'..."
    sed -i '/^HOOKS=/s/\budev\b/udev plymouth/' "${_conf}"
else
    echo "plymouth hook: neither 'kms', 'systemd', nor 'udev' found in HOOKS; skipping." >&2
    exit 0
fi

echo "==> plymouth: regenerating initramfs..."
mkinitcpio -P
