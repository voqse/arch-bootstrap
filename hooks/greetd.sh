#!/usr/bin/env bash
# Hook: greetd
# Enables greetd with autologin into niri for the bootstrap user (collected
# interactively at the start of bootstrap.sh); agreety stays configured as
# the fallback prompt, used when the initial session exits or autologin
# cannot start.
# Ref: https://wiki.archlinux.org/title/Greetd

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${HOOK_DIR}/../config.sh"

_GREETD_USER="${INSTALL_USERNAME:-user}"

mkdir -p /etc/greetd
cat > /etc/greetd/config.toml <<EOF
[terminal]
vt = 1

# Autologin for the bootstrap user; the default_session below is the
# fallback shown after the initial session exits.
[initial_session]
command = "niri-session"
user = "${_GREETD_USER}"

[default_session]
command = "agreety --cmd niri-session"
user = "greeter"
EOF

systemctl enable greetd
