#!/usr/bin/env bash
# =============================================================================
# Module 02 — Disk partitioning, formatting and mounting
#
# Partition layouts (GPT / UEFI):
#   SWAP_TYPE=file | none:
#     Part 1 — 512 MiB  EFI System Partition  (FAT32)
#     Part 2 — remainder                       (ext4)
#
#   SWAP_TYPE=partition:
#     Part 1 — 512 MiB  EFI System Partition  (FAT32)
#     Part 2 — SWAP_SIZE Linux swap            (swap)
#     Part 3 — remainder                       (ext4)
#
# Ref: https://wiki.archlinux.org/title/Installation_guide#Partition_the_disks
# =============================================================================

module_disk() {
    section "Disk partitioning"

    _select_disk
    _confirm_disk
    _partition_disk
    _format_partitions
    _mount_partitions
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

_list_disks() {
    lsblk -d -n -o NAME,SIZE,MODEL,TYPE | grep -E 'disk$' | nl -w2 -s') '
}

_select_disk() {
    # Use config value if provided
    if [[ -n "${DISK:-}" ]]; then
        info "Using disk from config: ${DISK}"
        return
    fi

    echo
    info "Available disks:"
    echo
    _list_disks
    echo

    local disk_list
    mapfile -t disk_list < <(lsblk -d -n -o NAME,TYPE | grep -E 'disk$' | awk '{print $1}')
    local count="${#disk_list[@]}"

    if [[ $count -eq 0 ]]; then
        die "No disks found."
    fi

    local choice
    while true; do
        ask_value "Select disk number (1-${count})"
        choice="$REPLY"
        if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= count )); then
            DISK="/dev/${disk_list[$((choice - 1))]}"
            break
        fi
        warn "Invalid selection. Enter a number between 1 and ${count}."
    done

    info "Selected disk: ${DISK}"
}

_confirm_disk() {
    echo
    warn "ALL DATA ON ${DISK} WILL BE DESTROYED!"
    lsblk "${DISK}"
    echo
    ask_yn "Proceed with partitioning ${DISK}?" || die "Aborted by user."
}

_partition_disk() {
    info "Partitioning ${DISK}..."

    # Wipe existing partition table
    run sgdisk --zap-all "${DISK}"

    if [[ "${SWAP_TYPE:-file}" == "partition" ]]; then
        # EFI | SWAP | root
        run parted -s "${DISK}" \
            mklabel gpt \
            mkpart ESP fat32 1MiB 513MiB \
            set 1 esp on \
            mkpart swap linux-swap 513MiB "$(_swap_end)" \
            mkpart root ext4 "$(_swap_end)" 100%
    else
        # EFI | root  (swapfile or no swap)
        run parted -s "${DISK}" \
            mklabel gpt \
            mkpart ESP fat32 1MiB 513MiB \
            set 1 esp on \
            mkpart root ext4 513MiB 100%
    fi

    # Let the kernel re-read the partition table
    run partprobe "${DISK}"
    sleep 1
}

# Convert SWAP_SIZE (e.g. "16G", "4096M") to a parted-compatible end position
# starting from 513MiB.
_swap_end() {
    local size="${SWAP_SIZE:-16G}"
    local num="${size%[GgMm]}"
    local unit="${size: -1}"

    case "${unit^^}" in
        G) echo "$((513 + num * 1024))MiB" ;;
        M) echo "$((513 + num))MiB" ;;
        *) die "Unsupported SWAP_SIZE unit: ${unit}. Use G or M." ;;
    esac
}

# Return the partition device node for partition number N.
# Handles both /dev/sdX (sdX1) and /dev/nvme0nX (nvme0n1p1) naming.
_part() {
    local disk="${DISK}" n="$1"
    if [[ "${disk}" =~ nvme|mmcblk ]]; then
        echo "${disk}p${n}"
    else
        echo "${disk}${n}"
    fi
}

# Compute the ext4 reserved-blocks percentage for the given block device.
# Reserved space is proportional to disk size so that large disks don't waste
# gigabytes on blocks that are rarely needed by root.
#   ≤ 512 GiB → 1 %
#   ≤ 1024 GiB → 0.5 %
#   > 1024 GiB → 0.25 %
_reserved_percent() {
    local dev="$1"
    local size_bytes
    size_bytes=$(blockdev --getsize64 "${dev}" 2>/dev/null || echo 0)
    local gib=$(( size_bytes / 1024 / 1024 / 1024 ))
    if (( gib <= 512 )); then
        echo 1
    elif (( gib <= 1024 )); then
        echo 0.5
    else
        echo 0.25
    fi
}

_format_partitions() {
    info "Formatting partitions..."

    local efi_part root_part
    efi_part=$(_part 1)

    if [[ "${SWAP_TYPE:-file}" == "partition" ]]; then
        local swap_part
        swap_part=$(_part 2)
        root_part=$(_part 3)

        run mkfs.fat -F32 "${efi_part}"
        run mkswap "${swap_part}"
        run mkfs.ext4 -F -m "$(_reserved_percent "${root_part}")" "${root_part}"

        EFI_PART="${efi_part}"
        SWAP_PART="${swap_part}"
        ROOT_PART="${root_part}"
    else
        root_part=$(_part 2)

        run mkfs.fat -F32 "${efi_part}"
        run mkfs.ext4 -F -m "$(_reserved_percent "${root_part}")" "${root_part}"

        EFI_PART="${efi_part}"
        SWAP_PART=""
        ROOT_PART="${root_part}"
    fi

    success "Partitions formatted."
}

_mount_partitions() {
    info "Mounting partitions..."

    local efi_mountpoint="${EFI_MOUNTPOINT:-/boot}"

    run mount "${ROOT_PART}" /mnt
    run mkdir -p "/mnt${efi_mountpoint}"
    run mount "${EFI_PART}" "/mnt${efi_mountpoint}"

    case "${SWAP_TYPE:-file}" in
        partition)
            run swapon "${SWAP_PART}"
            ;;
        file)
            _create_swapfile
            ;;
        none)
            info "Swap disabled."
            ;;
        *)
            die "Unknown SWAP_TYPE '${SWAP_TYPE}'. Use: file, partition, none."
            ;;
    esac

    success "Partitions mounted."
    lsblk "${DISK}"
}

_create_swapfile() {
    local swap_size="${SWAP_SIZE:-16G}"
    local swap_path="/mnt/swap/swapfile"

    info "Creating swapfile (${swap_size}) at ${swap_path}..."

    run mkdir -p /mnt/swap

    # Disable Copy-on-Write for the swap directory (no-op on ext4, safe on btrfs)
    chattr +C /mnt/swap 2>/dev/null || true

    run fallocate -l "${swap_size}" "${swap_path}"
    run chmod 600 "${swap_path}"
    run mkswap "${swap_path}"
    run swapon "${swap_path}"

    # Export for _export_config
    SWAP_FILE="/swap/swapfile"

    success "Swapfile created and activated."
}
