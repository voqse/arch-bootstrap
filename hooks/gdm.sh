#!/usr/bin/env bash
# Hook: gdm
# Enables the GNOME Display Manager (login screen / session launcher) and
# configures it via dconf:
#   - Solid #000000 (black) desktop background and screensaver
#   - No distribution logo on the login screen
# Ref: https://wiki.archlinux.org/title/GDM#Installation

systemctl enable gdm

# ---------------------------------------------------------------------------
# GDM login screen — GDM dconf database
# ---------------------------------------------------------------------------
if [[ ! -f /etc/dconf/profile/gdm ]]; then
    cat > /etc/dconf/profile/gdm <<'EOF'
user-db:user
system-db:gdm
file-db:/usr/share/gdm/greeter-dconf-defaults
EOF
fi

mkdir -p /etc/dconf/db/gdm.d
cat > /etc/dconf/db/gdm.d/00-background <<'EOF'
[org/gnome/desktop/background]
picture-options='none'
primary-color='#000000'
color-shading-type='solid'
picture-uri=''
picture-uri-dark=''

[org/gnome/desktop/screensaver]
picture-options='none'
primary-color='#000000'
color-shading-type='solid'
picture-uri=''

[org/gnome/login-screen]
logo=''
EOF

dconf update
