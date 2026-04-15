#!/usr/bin/env bash
# Hook: gnome-shell
# Configures GNOME Shell via system-wide dconf overrides:
#   - Solid #000000 desktop background for user sessions
#   - Enables gnome-shell-extension-appindicator system-wide
#   - Custom keyboard shortcuts: Ctrl+Alt+T (terminal), Ctrl+Shift+Esc (btop)

# ---------------------------------------------------------------------------
# 1. User sessions — system-wide dconf local override
# ---------------------------------------------------------------------------
mkdir -p /etc/dconf/profile
# Only create the user profile if it doesn't already exist
if [[ ! -f /etc/dconf/profile/user ]]; then
    cat > /etc/dconf/profile/user <<'EOF'
user-db:user
system-db:local
EOF
fi

mkdir -p /etc/dconf/db/local.d
cat > /etc/dconf/db/local.d/00-background <<'EOF'
[org/gnome/desktop/background]
picture-options='none'
primary-color='#000000'
color-shading-type='solid'
picture-uri=''
picture-uri-dark=''
EOF

cat > /etc/dconf/db/local.d/01-extensions <<'EOF'
[org/gnome/shell]
enabled-extensions=['appindicatorsupport@rgcjonas.gmail.com']
EOF

cat > /etc/dconf/db/local.d/02-keybindings <<'EOF'
[org/gnome/settings-daemon/plugins/media-keys]
# Fresh-install bootstrap: no prior custom keybindings exist, so a full assignment is safe here.
custom-keybindings=['/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/', '/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/']

[org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0]
binding='<Control><Alt>t'
command='kgx'
name='Terminal'

[org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1]
binding='<Control><Shift>Escape'
command='kgx -- btop'
name='Task Manager'
EOF

# ---------------------------------------------------------------------------
# 2. Compile dconf databases
# ---------------------------------------------------------------------------
dconf update
