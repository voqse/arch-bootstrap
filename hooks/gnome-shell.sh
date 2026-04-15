#!/usr/bin/env bash
# Hook: gnome-shell
# Configures GNOME Shell via system-wide dconf overrides:
#   - Solid #000000 desktop background for user sessions
#   - Enables gnome-shell-extension-appindicator system-wide

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

# ---------------------------------------------------------------------------
# 2. Compile dconf databases
# ---------------------------------------------------------------------------
dconf update
