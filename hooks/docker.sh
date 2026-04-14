#!/usr/bin/env bash
# Hook: docker
# Configures the system for Docker Engine and Docker Desktop:
#   - Adds the install user to the docker group (rootless CLI access).
#   - Adds the install user to the kvm group (required by Docker Desktop,
#     which runs its engine inside a KVM virtual machine).
#   - Writes /etc/subuid and /etc/subgid entries for the install user
#     (required by Docker Desktop for user-namespace file sharing).
# Ref: https://wiki.archlinux.org/title/Docker#Installation
# Ref: https://docs.docker.com/desktop/setup/install/linux/

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

    # Add to kvm group — required by Docker Desktop (runs engine in a KVM VM)
    if getent group kvm > /dev/null 2>&1; then
        usermod -aG kvm "${INSTALL_USERNAME}"
    else
        echo "Warning: kvm group not found — skipping kvm usermod for '${INSTALL_USERNAME}'." >&2
    fi

    # Write subuid/subgid entries — required by Docker Desktop for file sharing
    if ! grep -q "^${INSTALL_USERNAME}:" /etc/subuid 2>/dev/null; then
        echo "${INSTALL_USERNAME}:100000:65536" >> /etc/subuid
    fi
    if ! grep -q "^${INSTALL_USERNAME}:" /etc/subgid 2>/dev/null; then
        echo "${INSTALL_USERNAME}:100000:65536" >> /etc/subgid
    fi
fi
