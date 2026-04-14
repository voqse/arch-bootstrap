#!/usr/bin/env bash
# Hook: docker
# Adds the install user to the docker group so that Docker can be used
# without sudo.
# Ref: https://wiki.archlinux.org/title/Docker#Installation

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${HOOK_DIR}/../config.sh"

if [[ -n "${INSTALL_USERNAME:-}" ]]; then
    if getent group docker > /dev/null 2>&1; then
        usermod -aG docker "${INSTALL_USERNAME}"
    else
        echo "Warning: docker group not found — skipping usermod for '${INSTALL_USERNAME}'." >&2
    fi
fi
