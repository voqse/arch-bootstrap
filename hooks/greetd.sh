#!/usr/bin/env bash
# Hook: greetd
# Enables greetd and configures agreety to launch niri-session after login.
# Ref: https://wiki.archlinux.org/title/Greetd

mkdir -p /etc/greetd
cat > /etc/greetd/config.toml <<'EOF'
[terminal]
vt = 1

[default_session]
command = "agreety --cmd niri-session"
user = "greeter"
EOF

systemctl enable greetd
