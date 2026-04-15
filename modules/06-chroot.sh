#!/usr/bin/env bash
# =============================================================================
# Module 06 — Chroot configuration
# Copies required files into /mnt and runs the chroot configurator.
# Ref: https://wiki.archlinux.org/title/Installation_guide#Chroot
# =============================================================================

module_chroot() (
    section "Chroot configuration"

    local script_dir chroot_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    chroot_dir="/mnt/root/arch-bootstrap-chroot"

    trap 'rm -rf -- "${chroot_dir}"' EXIT INT TERM HUP

    # Copy chroot scripts and hooks into the new system
    info "Copying chroot scripts into /mnt..."
    cp -r "${script_dir}/chroot"  "${chroot_dir}"
    cp -r "${script_dir}/hooks"   "${chroot_dir}/hooks"
    cp    "${script_dir}/lib.sh"  "${chroot_dir}/lib.sh"

    # Write the resolved config so the chroot environment reads the same values
    _export_config > "${chroot_dir}/config.sh"

    chmod +x "${chroot_dir}/configure.sh"

    # arch-chroot bind-mounts the host's /run inside the chroot.  When
    # mkinitcpio -P runs inside the chroot (after the plymouth hook is added),
    # tmpfiles rules or post-hooks from the target's mkinitcpio can write new
    # content—including the plymouth hook—into the host's
    # /run/initramfs/mkinitcpio-shutdown.conf.  At host shutdown the
    # mkinitcpio-generate-shutdown-ramfs.service reads that file, calls
    # Plymouth's build() -> plymouth-set-default-theme (Python), and fails
    # under MemoryDenyWriteExecute=yes.  Preserve and restore the file so the
    # host's shutdown behaviour is unaffected by the installation.
    local _shutdown_conf="/run/initramfs/mkinitcpio-shutdown.conf"
    local _shutdown_conf_backup=""
    local _shutdown_conf_existed=false
    if [[ -f "${_shutdown_conf}" ]]; then
        _shutdown_conf_existed=true
        _shutdown_conf_backup="$(mktemp -p /run mkinitcpio-shutdown-conf.XXXXXX 2>/dev/null || true)"
        if [[ -n "${_shutdown_conf_backup}" ]]; then
            chmod 600 -- "${_shutdown_conf_backup}"
            cp -- "${_shutdown_conf}" "${_shutdown_conf_backup}" || {
                rm -f -- "${_shutdown_conf_backup}"
                _shutdown_conf_backup=""
            }
        fi
    fi

    info "Entering chroot..."
    run arch-chroot /mnt /root/arch-bootstrap-chroot/configure.sh

    # Restore /run/initramfs/mkinitcpio-shutdown.conf to the state it was in
    # before the chroot so the host's shutdown ramfs service works correctly.
    if [[ "${_shutdown_conf_existed}" == true ]]; then
        if [[ -n "${_shutdown_conf_backup}" && -f "${_shutdown_conf_backup}" ]]; then
            cp -- "${_shutdown_conf_backup}" "${_shutdown_conf}"
        fi
        # If backup was not available, leave the file as-is.
    elif [[ -f "${_shutdown_conf}" ]]; then
        rm -f -- "${_shutdown_conf}"
    fi
    [[ -n "${_shutdown_conf_backup}" ]] && rm -f -- "${_shutdown_conf_backup}"

    success "Chroot configuration complete."
)

# Serialise all config variables into a sourceable shell file.
_export_config() {
    printf '%s\n' '#!/usr/bin/env bash'
    printf '%s\n' '# Auto-generated config — do not edit manually.'

    # Arrays — use declare -p for correct round-tripping of elements with spaces
    if declare -p LOCALES >/dev/null 2>&1; then
        declare -p LOCALES
    else
        printf '%s\n' 'declare -a LOCALES=()'
    fi

    printf 'LANG=%q\n'             "${LANG}"
    printf 'KEYMAP=%q\n'           "${KEYMAP}"
    printf 'FONT=%q\n'             "${FONT}"
    printf 'XKBLAYOUT=%q\n'        "${XKBLAYOUT:-}"
    printf 'XKBOPTIONS=%q\n'       "${XKBOPTIONS:-}"
    printf 'TIMEZONE=%q\n'         "${TIMEZONE}"
    printf 'HOSTNAME=%q\n'         "${HOSTNAME}"
    printf 'INSTALL_USERNAME=%q\n' "${INSTALL_USERNAME:-}"
    printf 'INSTALL_USER_PASSWORD=%q\n' "${INSTALL_USER_PASSWORD:-}"
    printf 'ROOT_PASSWORD=%q\n'    "${ROOT_PASSWORD:-}"

    if declare -p USERS >/dev/null 2>&1; then
        declare -p USERS
    else
        printf '%s\n' 'declare -a USERS=()'
    fi

    printf 'EFI_MOUNTPOINT=%q\n'          "${EFI_MOUNTPOINT:-/boot}"

    if declare -p PACKAGES >/dev/null 2>&1; then
        declare -p PACKAGES
    else
        printf '%s\n' 'declare -a PACKAGES=()'
    fi

    if declare -p SERVICES >/dev/null 2>&1; then
        declare -p SERVICES
    else
        printf '%s\n' 'declare -a SERVICES=()'
    fi

    printf 'EFI_PART=%q\n'   "${EFI_PART:-}"
    printf 'ROOT_PART=%q\n'  "${ROOT_PART:-}"
    printf 'SWAP_TYPE=%q\n'  "${SWAP_TYPE:-file}"
    printf 'SWAP_PART=%q\n'  "${SWAP_PART:-}"
    printf 'SWAP_FILE=%q\n'  "${SWAP_FILE:-}"
    printf 'DISK=%q\n'       "${DISK:-}"
    printf 'HIBERNATE_DELAY=%q\n' "${HIBERNATE_DELAY:-}"

    if declare -p KERNEL_PARAMS >/dev/null 2>&1; then
        declare -p KERNEL_PARAMS
    else
        printf '%s\n' 'declare -a KERNEL_PARAMS=()'
    fi

    if declare -p YAY_PACKAGES >/dev/null 2>&1; then
        declare -p YAY_PACKAGES
    else
        printf '%s\n' 'declare -a YAY_PACKAGES=()'
    fi
}
