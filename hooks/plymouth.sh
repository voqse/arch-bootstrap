#!/usr/bin/env bash
# Hook: plymouth
# Inserts the 'plymouth' hook into mkinitcpio HOOKS so that the Plymouth
# splash screen is shown on early boot, and sets the theme to 'bgrt'
# (shows the OEM/UEFI firmware logo from the ACPI BGRT table, hides the
# distribution logo).
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
# shellcheck source=/dev/null
source "${HOOK_DIR}/../config.sh"

# Set the bgrt theme (shows OEM/UEFI firmware logo, hides distribution logo).
# 'bgrt' is bundled with the plymouth package, so it is always available.
# Run unconditionally so the theme is applied even when the mkinitcpio hook
# was already inserted by a previous run.
plymouth-set-default-theme bgrt

# Ensure the boot entry enables the Plymouth splash screen at boot.
# config.sh provides EFI_MOUNTPOINT; default to /boot when it is unset.
_esp="${EFI_MOUNTPOINT:-/boot}"
_loader_default="arch.conf"
_loader_conf="${_esp}/loader/loader.conf"
if [[ -f "${_loader_conf}" ]]; then
    if ! _loader_default="$(awk '$1 == "default" { print $2; exit }' "${_loader_conf}")"; then
        warn "plymouth hook: failed to read ${_loader_conf}; falling back to ${_loader_default}."
    fi
fi
_loader_default="${_loader_default:-arch.conf}"

_loader_entry="${_esp}/loader/entries/${_loader_default}"
if [[ -f "${_loader_entry}" ]]; then
    if ! _tmp_loader_entry="$(mktemp -p "$(dirname "${_loader_entry}")" "$(basename "${_loader_entry}").XXXXXX")"; then
        warn "plymouth hook: failed to create a temporary file next to ${_loader_entry}; skipping splash kernel parameter."
        _tmp_loader_entry=""
    fi
    if [[ -n "${_tmp_loader_entry}" ]] && awk '
        BEGIN { saw_options = 0; saw_splash = 0; updated = 0 }
        {
            lines[NR] = $0
            if ($0 ~ /^options /) {
                saw_options = 1
                if ($0 ~ /(^|[[:space:]])splash([[:space:]]|$)/) {
                    saw_splash = 1
                }
            }
        }
        END {
            if (!saw_options) {
                exit 2
            }

            for (i = 1; i <= NR; i++) {
                if (!saw_splash && !updated && lines[i] ~ /^options /) {
                    print lines[i] " splash"
                    updated = 1
                } else {
                    print lines[i]
                }
            }
        }
    ' "${_loader_entry}" > "${_tmp_loader_entry}"; then
        if cmp -s "${_loader_entry}" "${_tmp_loader_entry}"; then
            rm -f "${_tmp_loader_entry}"
        else
            mv "${_tmp_loader_entry}" "${_loader_entry}"
        fi
    else
        _rc=$?
        rm -f "${_tmp_loader_entry}"
        if [[ ${_rc} -eq 2 ]]; then
            warn "plymouth hook: no 'options' line found in ${_loader_entry}; add one manually or verify the boot loader configuration."
        else
            warn "plymouth hook: failed to update kernel options in ${_loader_entry}."
        fi
    fi
else
    warn "plymouth hook: loader entry not found at ${_loader_entry}; skipping splash kernel parameter."
fi

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
