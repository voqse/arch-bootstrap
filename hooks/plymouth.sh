#!/usr/bin/env bash
# Hook: plymouth
# Inserts the 'plymouth' hook into mkinitcpio HOOKS and regenerates the
# initramfs so that the Plymouth splash screen is shown on early boot.
#
# Placement rules (Arch Wiki):
#   - 'plymouth' must come after 'kms' (KMS must be initialised first).
#   - 'systemd' must appear before 'plymouth'.
#   - Insert after whichever of 'kms'/'systemd' occurs later in HOOKS so
#     both constraints are satisfied regardless of their relative order.
#   - Fallback: place after 'udev'.
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

# Return the zero-based position of a hook in HOOKS=(...), or -1 if absent.
_hook_index() {
    local hook_name=$1
    local hooks_line hooks_body
    local -a hooks
    local i

    hooks_line=$(grep -m1 '^HOOKS=(' "${_conf}" 2>/dev/null || true)
    if [[ -z "${hooks_line}" ]]; then
        echo -1
        return 0
    fi

    hooks_body=${hooks_line#HOOKS=(}
    hooks_body=${hooks_body%)}
    read -r -a hooks <<< "${hooks_body}"

    for i in "${!hooks[@]}"; do
        if [[ "${hooks[i]}" == "${hook_name}" ]]; then
            echo "${i}"
            return 0
        fi
    done

    echo -1
}

if _hooks_contain plymouth; then
    echo "==> plymouth: mkinitcpio HOOKS already contains plymouth; skipping initramfs regeneration."
    exit 0
fi

_kms_index=$(_hook_index kms)
_systemd_index=$(_hook_index systemd)

if (( _kms_index >= 0 || _systemd_index >= 0 )); then
    if (( _kms_index > _systemd_index )); then
        _insert_after=kms
    else
        _insert_after=systemd
    fi
    echo "==> plymouth: adding plymouth hook after '${_insert_after}'..."
    sed -E -i "/^HOOKS=/s/([[:space:](])${_insert_after}([[:space:])])/\1${_insert_after} plymouth\2/" "${_conf}"
elif _hooks_contain udev; then
    echo "==> plymouth: adding plymouth hook after 'udev'..."
    sed -E -i '/^HOOKS=/s/([[:space:](])udev([[:space:])])/\1udev plymouth\2/' "${_conf}"
else
    echo "plymouth hook: neither 'kms', 'systemd', nor 'udev' found in HOOKS; skipping." >&2
    exit 0
fi

echo "==> plymouth: regenerating initramfs..."
mkinitcpio -P
