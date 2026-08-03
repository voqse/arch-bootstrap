#!/usr/bin/env bash
# Hook: snapper
# Creates the snapper root config for pacman-transaction snapshots (snap-pac)
# and enables number-based cleanup. Deliberately minimal: timeline snapshots
# stay off — the only scenario served is "an update broke the system, roll
# back by hand". Snapshots live on the same disk and are not backups.
# Ref: https://wiki.archlinux.org/title/Snapper#Configuration_of_snapper_and_mount_point
#
# snapper create-config insists on creating its own /.snapshots subvolume, so
# the standard Arch dance applies: unmount our @snapshots, let snapper create
# the config, delete the nested subvolume it made, remount @snapshots (fstab
# already has the entry via genfstab).

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${HOOK_DIR}/../config.sh"

if [[ "${FILESYSTEM:-btrfs}" != "btrfs" ]]; then
    echo "Root filesystem is not btrfs — skipping snapper configuration."
    exit 0
fi

if mountpoint -q /.snapshots; then
    umount /.snapshots
fi
rmdir /.snapshots 2>/dev/null || true

# --no-dbus: no dbus daemon inside the chroot
snapper --no-dbus create-config /

# Drop the subvolume snapper nested under @; snapshots must live in the
# top-level @snapshots subvolume or root snapshots would pin themselves.
btrfs subvolume delete /.snapshots
mkdir /.snapshots
mount /.snapshots
chmod 750 /.snapshots

# Timeline off, keep roughly the last 5 update transactions (pre+post pairs).
sed -i \
    -e 's/^TIMELINE_CREATE=.*/TIMELINE_CREATE="no"/' \
    -e 's/^NUMBER_LIMIT=.*/NUMBER_LIMIT="10"/' \
    -e 's/^NUMBER_LIMIT_IMPORTANT=.*/NUMBER_LIMIT_IMPORTANT="10"/' \
    /etc/snapper/configs/root

# Prunes number-cleanup snapshots past NUMBER_LIMIT; timeline timer stays off.
systemctl enable snapper-cleanup.timer
# snapper's packaging leaves snapper-timeline.timer enabled — force it off.
systemctl disable snapper-timeline.timer
