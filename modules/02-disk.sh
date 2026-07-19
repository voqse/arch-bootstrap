#!/usr/bin/env bash
# Module 02 — Disk partitioning, formatting and mounting
#
# Partition layouts (GPT / UEFI):
#   SWAP_TYPE=file | none:
#     Part 1 — 1024 MiB  EFI System Partition  (FAT32)
#     Part 2 — remainder                        (FILESYSTEM: btrfs or ext4)
#
#   SWAP_TYPE=partition:
#     Part 1 — 1024 MiB  EFI System Partition  (FAT32)
#     Part 2 — SWAP_SIZE Linux swap             (swap)
#     Part 3 — remainder                        (FILESYSTEM: btrfs or ext4)
#
# With FILESYSTEM=btrfs (default) the root partition is split into
# subvolumes (see BTRFS_SUBVOLS below) mounted with BTRFS_MOUNT_OPTS.
# The ESP is mounted with umask=0077 so that the systemd-boot random seed
# is not world readable (genfstab propagates the options into fstab).
#
# Ref: https://wiki.archlinux.org/title/Installation_guide#Partition_the_disks
# Ref: https://wiki.archlinux.org/title/Btrfs#Compression

# Btrfs layout — "subvolume:mountpoint" pairs; @ must stay first (mounted as /).
# @swap is created on demand when SWAP_TYPE=file.
BTRFS_SUBVOLS=(
    "@:/"
    "@home:/home"
    "@log:/var/log"
    "@pkg:/var/cache/pacman/pkg"
    # Docker layers/volumes out of root snapshots: image data would otherwise
    # be pinned by every snapshot of @ (deleted images keep occupying space).
    "@docker:/var/lib/docker"
    "@snapshots:/.snapshots"
)
BTRFS_MOUNT_OPTS="noatime,compress=zstd"

# FAT has no Unix permissions; without a umask the ESP (and the systemd-boot
# random seed on it) is world readable and bootctl warns about it.
ESP_MOUNT_OPTS="umask=0077"

# Helpers

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
            mkpart ESP fat32 1MiB 1025MiB \
            set 1 esp on \
            mkpart swap linux-swap 1025MiB "$(_swap_end)" \
            mkpart root "${FILESYSTEM}" "$(_swap_end)" 100%
    else
        # EFI | root  (swapfile or no swap)
        run parted -s "${DISK}" \
            mklabel gpt \
            mkpart ESP fat32 1MiB 1025MiB \
            set 1 esp on \
            mkpart root "${FILESYSTEM}" 1025MiB 100%
    fi

    # Let the kernel re-read the partition table
    run partprobe "${DISK}"
    sleep 1
}

# Convert SWAP_SIZE (e.g. "16G", "4096M") to a parted-compatible end position
# starting from 1025MiB.
_swap_end() {
    local size="${SWAP_SIZE}"
    local num="${size%[GgMm]}"
    local unit="${size: -1}"

    case "${unit^^}" in
        G) echo "$((1025 + num * 1024))MiB" ;;
        M) echo "$((1025 + num))MiB" ;;
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

# Return the ext4 reserved-blocks percentage (always 1%) for the given block device.
_reserved_percent() {
    echo 1
}

# Format the root partition according to FILESYSTEM.
_format_root() {
    local root_part="$1"

    case "${FILESYSTEM}" in
        btrfs)
            run mkfs.btrfs -f "${root_part}"
            ;;
        ext4)
            run mkfs.ext4 -F -m "$(_reserved_percent "${root_part}")" "${root_part}"
            ;;
        *)
            die "Unknown FILESYSTEM '${FILESYSTEM}'. Use: btrfs, ext4."
            ;;
    esac
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
        _format_root "${root_part}"

        EFI_PART="${efi_part}"
        SWAP_PART="${swap_part}"
        ROOT_PART="${root_part}"
    else
        root_part=$(_part 2)

        run mkfs.fat -F32 "${efi_part}"
        _format_root "${root_part}"

        EFI_PART="${efi_part}"
        SWAP_PART=""
        ROOT_PART="${root_part}"
    fi

    success "Partitions formatted."
}

# Create the btrfs subvolume layout and mount every subvolume in place.
_mount_btrfs() {
    info "Creating btrfs subvolumes..."

    run mount "${ROOT_PART}" /mnt

    local entry subvol target
    for entry in "${BTRFS_SUBVOLS[@]}"; do
        run btrfs subvolume create "/mnt/${entry%%:*}"
    done

    # Swapfiles must live outside the snapshotted root subvolume: btrfs
    # refuses to snapshot a subvolume that contains an active swapfile.
    if [[ "${SWAP_TYPE:-file}" == "file" ]]; then
        run btrfs subvolume create /mnt/@swap
    fi

    run umount /mnt

    info "Mounting subvolumes..."
    for entry in "${BTRFS_SUBVOLS[@]}"; do
        subvol="${entry%%:*}"
        target="${entry#*:}"
        [[ "${target}" == "/" ]] && target=""
        run mkdir -p "/mnt${target}"
        run mount -o "${BTRFS_MOUNT_OPTS},subvol=${subvol}" "${ROOT_PART}" "/mnt${target:-/}"
    done

    # No compression on the swap subvolume: swapfiles require NOCOW, which
    # is incompatible with compression anyway.
    if [[ "${SWAP_TYPE:-file}" == "file" ]]; then
        run mkdir -p /mnt/swap
        run mount -o "noatime,subvol=@swap" "${ROOT_PART}" /mnt/swap
    fi
}

_mount_partitions() {
    info "Mounting partitions..."

    local efi_mountpoint="${EFI_MOUNTPOINT:-/boot}"

    if [[ "${FILESYSTEM}" == "btrfs" ]]; then
        _mount_btrfs
    else
        run mount "${ROOT_PART}" /mnt
    fi
    run mkdir -p "/mnt${efi_mountpoint}"
    run mount -o "${ESP_MOUNT_OPTS}" "${EFI_PART}" "/mnt${efi_mountpoint}"

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
    local swap_size="${SWAP_SIZE}"
    local swap_path="/mnt/swap/swapfile"

    info "Creating swapfile (${swap_size}) at ${swap_path}..."

    if [[ "${FILESYSTEM}" == "btrfs" ]]; then
        # /mnt/swap is the dedicated @swap subvolume mounted by _mount_btrfs.
        # mkswapfile handles NOCOW, preallocation and mkswap in one step.
        # Ref: https://wiki.archlinux.org/title/Btrfs#Swap_file
        run btrfs filesystem mkswapfile --size "${swap_size}" "${swap_path}"
    else
        run mkdir -p /mnt/swap
        run fallocate -l "${swap_size}" "${swap_path}"
        run chmod 600 "${swap_path}"
        run mkswap "${swap_path}"
    fi

    run swapon "${swap_path}"

    # Export for _export_config
    SWAP_FILE="/swap/swapfile"

    success "Swapfile created and activated."
}

# Main

section "Disk partitioning"

FILESYSTEM="${FILESYSTEM:-btrfs}"
case "${FILESYSTEM}" in
    btrfs|ext4) ;;
    *) die "Unknown FILESYSTEM '${FILESYSTEM}'. Use: btrfs, ext4." ;;
esac

_select_disk
_confirm_disk
_partition_disk
_format_partitions
_mount_partitions
