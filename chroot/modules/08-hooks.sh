#!/usr/bin/env bash
# =============================================================================
# Chroot module — Per-package post-install hooks
# Reads the PACKAGES array from config; entries of the form "pkg:hook_name"
# will execute hooks/<hook_name>.sh inside the chroot.
# =============================================================================

chroot_package_hooks() {
    section "Package post-install hooks"

    local chroot_dir
    chroot_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

    local ran=0
    for entry in "${PACKAGES[@]}"; do
        local pkg hook
        pkg="${entry%%:*}"
        hook="${entry#*:}"

        # No hook defined (entry has no colon, or hook == pkg name with no script)
        if [[ "${hook}" == "${pkg}" ]] && [[ ! -f "${chroot_dir}/hooks/${hook}.sh" ]]; then
            continue
        fi

        local hook_file="${chroot_dir}/hooks/${hook}.sh"
        if [[ ! -f "${hook_file}" ]]; then
            warn "Hook script not found for package '${pkg}': ${hook_file}"
            continue
        fi

        info "Running hook for package '${pkg}': ${hook_file}"
        # shellcheck source=/dev/null
        bash "${hook_file}" || warn "Hook for '${pkg}' exited with error."
        ran=$((ran + 1))
    done

    if (( ran == 0 )); then
        info "No post-install hooks to run."
    else
        success "Ran ${ran} post-install hook(s)."
    fi
}
