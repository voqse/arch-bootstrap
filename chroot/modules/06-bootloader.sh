#!/usr/bin/env bash
# =============================================================================
# Chroot module — Boot loader
# Supported: systemd-boot (default), grub
# Ref: https://wiki.archlinux.org/title/Installation_guide#Boot_loader
# =============================================================================

chroot_bootloader() {
    section "Boot loader"

    case "${BOOTLOADER:-systemd-boot}" in
        systemd-boot) _install_systemd_boot ;;
        grub)         _install_grub ;;
        *)            die "Unsupported bootloader: ${BOOTLOADER}. Use 'systemd-boot' or 'grub'." ;;
    esac
}

# ---------------------------------------------------------------------------
# systemd-boot
# ---------------------------------------------------------------------------

_install_systemd_boot() {
    local esp="${EFI_MOUNTPOINT:-/boot}"

    info "Installing systemd-boot to ${esp}..."
    run bootctl --esp-path="${esp}" install

    # Loader configuration
    mkdir -p "${esp}/loader"
    cat > "${esp}/loader/loader.conf" <<EOF
default arch.conf
timeout 0
console-mode auto
editor no
EOF

    # Boot entry
    mkdir -p "${esp}/loader/entries"

    # Detect microcode images present on the ESP
    local microcode_lines=""
    for uc in amd-ucode intel-ucode; do
        if [[ -f "${esp}/${uc}.img" ]]; then
            microcode_lines+="initrd  /${uc}.img\n"
        fi
    done

    # Root device by UUID (stable across renames)
    local root_uuid
    root_uuid=$(blkid -s UUID -o value "${ROOT_PART}")

    # Kernel command line — include swap resume offset for swapfile hibernation
    local cmdline="root=UUID=${root_uuid} rw quiet"
    if _has_package "plymouth"; then
        cmdline+=" splash"
    fi
    if [[ "${SWAP_TYPE:-file}" == "file" && -n "${SWAP_FILE:-}" ]]; then
        local swap_offset
        # Physical offset of extent 0 — matches the first data line: "   0:  0..N:  OFFSET..N:..."
        swap_offset=$(filefrag -v "${SWAP_FILE}" 2>/dev/null \
            | awk '/^ *0:/ { sub(/:$/, "", $4); split($4, blocks, /\.\./); print blocks[1]; exit }')
        if [[ -n "${swap_offset}" ]]; then
            cmdline+=" resume=UUID=${root_uuid} resume_offset=${swap_offset}"
        fi
    fi
    if [[ ${#KERNEL_PARAMS[@]} -gt 0 ]]; then
        cmdline+=" ${KERNEL_PARAMS[*]}"
    fi

    cat > "${esp}/loader/entries/arch.conf" <<EOF
title   Arch Linux
linux   /vmlinuz-linux
$(printf '%b' "${microcode_lines}")initrd  /initramfs-linux.img
options ${cmdline}
EOF

    # Enable automatic EFI binary updates whenever systemd is upgraded.
    # Ref: https://wiki.archlinux.org/title/Systemd-boot#Automatic_update
    systemctl enable systemd-boot-update.service
    info "systemd-boot-update.service enabled."

    success "systemd-boot installed and configured."
}

# ---------------------------------------------------------------------------
# GRUB
# ---------------------------------------------------------------------------

_install_grub() {
    require_var DISK

    local esp="${EFI_MOUNTPOINT:-/boot}"

    # Apply GRUB defaults before generating the config
    local grub_default="/etc/default/grub"
    _grub_set_value "${grub_default}" "GRUB_TIMEOUT"            0
    _grub_set_value "${grub_default}" "GRUB_TIMEOUT_STYLE"      "hidden"
    _grub_set_value "${grub_default}" "GRUB_DISABLE_OS_PROBER"  "true"
    if _has_package "plymouth"; then
        # Append 'splash' to the existing cmdline only if not already present.
        sed -i '/^GRUB_CMDLINE_LINUX_DEFAULT=/{/splash/!s/"$/ splash"/}' "${grub_default}"
        info "GRUB: appended 'splash' to GRUB_CMDLINE_LINUX_DEFAULT"
    fi
    if [[ ${#KERNEL_PARAMS[@]} -gt 0 ]]; then
        local _cmdline_line _cmdline_value
        for _param in "${KERNEL_PARAMS[@]}"; do
            # Read the current line fresh each iteration: _grub_set_value updates
            # the file in-place, so subsequent params must see the updated value.
            _cmdline_line="$(grep -m1 '^GRUB_CMDLINE_LINUX_DEFAULT=' "${grub_default}" 2>/dev/null || true)"
            # Check and append only on the GRUB_CMDLINE_LINUX_DEFAULT line.
            if ! echo "${_cmdline_line}" | grep -qF -- "${_param}"; then
                _cmdline_value="${_cmdline_line#GRUB_CMDLINE_LINUX_DEFAULT=}"
                _cmdline_value="${_cmdline_value#\"}"
                _cmdline_value="${_cmdline_value%\"}"
                if [[ -n "${_cmdline_value}" ]]; then
                    _cmdline_value="${_cmdline_value} ${_param}"
                else
                    _cmdline_value="${_param}"
                fi
                _grub_set_value "${grub_default}" "GRUB_CMDLINE_LINUX_DEFAULT" "\"${_cmdline_value}\""
            fi
        done
        info "GRUB: appended KERNEL_PARAMS to GRUB_CMDLINE_LINUX_DEFAULT"
        unset _param _cmdline_line _cmdline_value
    fi

    info "Installing GRUB for UEFI (bootloader-id: Linux Boot Manager)..."
    run grub-install \
        --target=x86_64-efi \
        "--efi-directory=${esp}" \
        "--bootloader-id=Linux Boot Manager" \
        "${DISK}"

    info "Generating GRUB configuration..."
    run grub-mkconfig -o /boot/grub/grub.cfg

    success "GRUB installed and configured."
}

# Set or replace a key=value pair in a GRUB defaults file.
_grub_set_value() {
    local file="$1" key="$2" value="$3"
    if grep -q "^${key}=" "${file}" 2>/dev/null; then
        sed -i "s|^${key}=.*|${key}=${value}|" "${file}"
    elif grep -q "^#${key}=" "${file}" 2>/dev/null; then
        sed -i "s|^#${key}=.*|${key}=${value}|" "${file}"
    else
        echo "${key}=${value}" >> "${file}"
    fi
    info "GRUB: ${key}=${value}"
}
