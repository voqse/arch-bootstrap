#!/usr/bin/env bash
# Hook: docker
# Adds the install user to the docker group for non-root access to the Docker
# daemon via the docker group.
# Security note: membership in the docker group grants access to the
# root-owned Docker socket and is effectively root-equivalent.
# Ref: https://wiki.archlinux.org/title/Docker#Installation

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${HOOK_DIR}/../config.sh"

if [[ -n "${INSTALL_USERNAME:-}" ]]; then
    # Add to docker group
    if getent group docker > /dev/null 2>&1; then
        usermod -aG docker "${INSTALL_USERNAME}"
    else
        echo "Warning: docker group not found — skipping docker usermod for '${INSTALL_USERNAME}'." >&2
    fi
fi

# Pin the storage driver: on btrfs older Docker auto-selected the "btrfs"
# driver, which spawns its own subvolumes per layer (pollutes `btrfs
# subvolume list`, complicates maintenance). Docker 23+ defaults to overlay2
# everywhere; the pin makes that explicit. Fresh install — no existing
# daemon.json to preserve.
# Ref: https://wiki.archlinux.org/title/Docker#Storage_driver
mkdir -p /etc/docker
if [[ ! -f /etc/docker/daemon.json ]]; then
    cat > /etc/docker/daemon.json <<'EOF'
{
    "storage-driver": "overlay2"
}
EOF
fi

# Enable socket-activated Docker daemon: on desktops this IS the on-demand
# mode — the daemon stays down until the first docker API call. Servers
# additionally enable docker.service via SERVICES in config/server.conf
# (24/7 stacks need restart policies applied at boot).
# Ref: https://wiki.archlinux.org/title/Docker#Installation
systemctl enable docker.socket
