#!/usr/bin/env bash
# Hook: reflector
# Writes /etc/xdg/reflector/reflector.conf from REFLECTOR_ARGS — the same
# arguments already used for the install-time mirror ranking in
# modules/03-mirrors.sh (single source of truth in the preset config) —
# and enables the weekly reflector.timer.
# Ref: https://wiki.archlinux.org/title/Reflector#systemd

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${HOOK_DIR}/../config.sh"

if ! declare -p REFLECTOR_ARGS &>/dev/null || [[ ${#REFLECTOR_ARGS[@]} -eq 0 ]]; then
    echo "Warning: REFLECTOR_ARGS not defined — skipping reflector.conf." >&2
    exit 0
fi

mkdir -p /etc/xdg/reflector

{
    echo "# Managed by arch-bootstrap (hooks/reflector.sh) — do not edit by hand."
    echo "# Arguments are defined once as REFLECTOR_ARGS in the preset config."
    echo "--save /etc/pacman.d/mirrorlist"
    printf '%s\n' "${REFLECTOR_ARGS[@]}"
} > /etc/xdg/reflector/reflector.conf

# Keep the last known-good mirrorlist for rollback before each refresh
# (the service runs under ProtectSystem=strict, so widen the writable path).
mkdir -p /etc/systemd/system/reflector.service.d
cat > /etc/systemd/system/reflector.service.d/backup.conf <<'EOF'
[Service]
ReadWritePaths=/etc/pacman.d
ExecStartPre=/usr/bin/cp -f /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.bak
EOF

# Weekly mirror refresh
systemctl enable reflector.timer
