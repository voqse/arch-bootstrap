#!/usr/bin/env bash
# =============================================================================
# Chroot module — Per-package post-install hooks
# Reads the PACKAGES array from config; entries of the form "pkg:hook_name"
# will execute hooks/<hook_name>.sh inside the chroot.
# =============================================================================

section "Package post-install hooks"

_hooks_chroot_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

_hooks_ran=0
for _hook_entry in "${PACKAGES[@]}"; do
    _hook_pkg="${_hook_entry%%:*}"
    _hook_name="${_hook_entry#*:}"

    # No hook defined (entry has no colon, or hook == pkg name with no script)
    if [[ "${_hook_name}" == "${_hook_pkg}" ]] && [[ ! -f "${_hooks_chroot_dir}/hooks/${_hook_name}.sh" ]]; then
        continue
    fi

    _hook_file="${_hooks_chroot_dir}/hooks/${_hook_name}.sh"
    if [[ ! -f "${_hook_file}" ]]; then
        warn "Hook script not found for package '${_hook_pkg}': ${_hook_file}"
        continue
    fi

    info "Running hook for package '${_hook_pkg}': ${_hook_file}"
    # shellcheck source=/dev/null
    bash "${_hook_file}" || warn "Hook for '${_hook_pkg}' exited with error."
    _hooks_ran=$((_hooks_ran + 1))
done

if (( _hooks_ran == 0 )); then
    info "No post-install hooks to run."
else
    success "Ran ${_hooks_ran} post-install hook(s)."
fi
