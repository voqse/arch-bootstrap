#!/usr/bin/env bash
# Chroot module — Boot loader (systemd-boot)
# Ref: https://wiki.archlinux.org/title/Installation_guide#Boot_loader

# systemd-boot

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
            microcode_lines+="initrd  /${uc}.img"$'\n'
        fi
    done

    # Root device by UUID (stable across renames)
    local root_uuid
    root_uuid=$(blkid -s UUID -o value "${ROOT_PART}")

    # Kernel command line — include swap resume offset for swapfile hibernation
    local cmdline="root=UUID=${root_uuid} rw quiet"
    if [[ "${FILESYSTEM:-btrfs}" == "btrfs" ]]; then
        cmdline="root=UUID=${root_uuid} rootflags=subvol=@ rw quiet"
    fi
    if [[ "${SWAP_TYPE:-file}" == "file" && -n "${SWAP_FILE:-}" ]]; then
        local swap_offset
        if [[ "${FILESYSTEM:-btrfs}" == "btrfs" ]]; then
            # filefrag reports logical extents on btrfs; the kernel needs the
            # physical offset, which btrfs-progs computes directly.
            # Ref: https://wiki.archlinux.org/title/Btrfs#Hibernation_into_swap_file
            swap_offset=$(btrfs inspect-internal map-swapfile -r "${SWAP_FILE}" 2>/dev/null)
        else
            # Physical offset of extent 0 — matches the first data line: "   0:  0..N:  OFFSET..N:..."
            swap_offset=$(filefrag -v "${SWAP_FILE}" 2>/dev/null \
                | awk '/^ *0:/ { sub(/:$/, "", $4); split($4, blocks, /\.\./); print blocks[1]; exit }')
        fi
        if [[ -n "${swap_offset}" ]]; then
            cmdline+=" resume=UUID=${root_uuid} resume_offset=${swap_offset}"
        fi
    elif [[ "${SWAP_TYPE:-file}" == "partition" && -n "${SWAP_PART:-}" ]]; then
        # Swap partition: resume points at the partition itself, no offset.
        # Ref: https://wiki.archlinux.org/title/Power_management/Suspend_and_hibernate#Hibernation
        local swap_uuid
        swap_uuid=$(blkid -s UUID -o value "${SWAP_PART}")
        if [[ -n "${swap_uuid}" ]]; then
            cmdline+=" resume=UUID=${swap_uuid}"
        fi
    fi
    if [[ ${#KERNEL_PARAMS[@]} -gt 0 ]]; then
        cmdline+=" ${KERNEL_PARAMS[*]}"
    fi

    cat > "${esp}/loader/entries/arch.conf" <<EOF
title   Arch Linux
linux   /vmlinuz-linux
${microcode_lines}initrd  /initramfs-linux.img
options ${cmdline}
EOF

    # Enable automatic EFI binary updates whenever systemd is upgraded.
    # Ref: https://wiki.archlinux.org/title/Systemd-boot#Automatic_update
    systemctl enable systemd-boot-update.service
    info "systemd-boot-update.service enabled."

    success "systemd-boot installed and configured."
}

# Main

section "Boot loader"

_install_systemd_boot
