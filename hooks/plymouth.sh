#!/usr/bin/env bash
# Hook: plymouth
# Inserts the 'plymouth' hook into mkinitcpio HOOKS so that the Plymouth
# splash screen is shown on early boot.
#
# Placement rules (Arch Wiki):
#   - 'plymouth' must come after 'kms' (KMS must be initialised first).
#   - 'systemd' must appear before 'plymouth'.
#   - Insert after whichever of 'kms'/'systemd' occurs later in HOOKS so
#     both constraints are satisfied regardless of their relative order.
#   - Fallback: place after 'udev'.
#
# Ref: https://wiki.archlinux.org/title/Plymouth#mkinitcpio

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "${HOOK_DIR}/../lib.sh"

if mkinitcpio_has_hook plymouth; then
    exit 0
fi

_kms_idx=$(mkinitcpio_hook_index kms)
_systemd_idx=$(mkinitcpio_hook_index systemd)

_rc=0
if (( _kms_idx >= 0 || _systemd_idx >= 0 )); then
    if (( _kms_idx > _systemd_idx )); then
        _anchor=kms
    else
        _anchor=systemd
    fi
    mkinitcpio_add_hook_after plymouth "${_anchor}" || _rc=$?
elif mkinitcpio_has_hook udev; then
    mkinitcpio_add_hook_after plymouth udev || _rc=$?
else
    warn "plymouth hook: neither 'kms', 'systemd', nor 'udev' found in HOOKS; skipping."
    exit 0
fi
unset _kms_idx _systemd_idx _anchor
exit "${_rc}"
