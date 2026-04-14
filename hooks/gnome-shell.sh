#!/usr/bin/env bash
# Hook: gnome-shell
# Sets a solid #000000 (black) desktop background for:
#   - All GNOME user sessions (via system-wide dconf override)
#   - GDM login screen (via GDM dconf database)

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

# ---------------------------------------------------------------------------
# 2. GDM login screen — GDM dconf database
# ---------------------------------------------------------------------------
if [[ ! -f /etc/dconf/profile/gdm ]]; then
    cat > /etc/dconf/profile/gdm <<'EOF'
user-db:user
system-db:gdm
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
EOF

# ---------------------------------------------------------------------------
# 3. Compile dconf databases
# ---------------------------------------------------------------------------
dconf update

# ---------------------------------------------------------------------------
# 4. Hide noisy utility entries from the app menu
# ---------------------------------------------------------------------------
# Copy each upstream .desktop file and append NoDisplay=true so that avahi
# browser tools and V4L utilities do not appear in GNOME Shell search or the
# application grid.  /usr/local/share/applications takes precedence over
# /usr/share/applications for same-named files.
mkdir -p /usr/local/share/applications

for _entry in \
    bssh.desktop \
    bvnc.desktop \
    avahi-discover.desktop \
    qv4l2.desktop \
    qvidcap.desktop
do
    _src="/usr/share/applications/${_entry}"
    _dst="/usr/local/share/applications/${_entry}"
    if [[ -f "${_src}" ]]; then
        cp "${_src}" "${_dst}"
        echo "NoDisplay=true" >> "${_dst}"
    fi
done
unset _entry _src _dst
