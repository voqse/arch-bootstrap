#!/usr/bin/env bash
# Hook: gnome-shell
# Configures GNOME Shell via system-wide dconf overrides:
#   - Solid #0e1722 desktop background for user sessions (app grid and
#     workspace overview inherit this colour)
#   - Solid #152131 top panel via a minimal system-level shell extension
#   - Enables AppIndicator tray icon extension
#   - Custom keyboard shortcuts: Ctrl+Alt+T (terminal), Ctrl+Shift+Esc (btop)
#   - GNOME power/suspend overrides when suspend-then-hibernate is enabled

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${HOOK_DIR}/../lib.sh"
# shellcheck source=/dev/null
source "${HOOK_DIR}/../config.sh"

# 1. User sessions — system-wide dconf local override
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
# Fresh-install bootstrap: no prior extensions exist, so a full assignment is safe here.
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

# 3. GNOME power settings — only when suspend-then-hibernate is configured.
if [[ -n "${HIBERNATE_DELAY:-}" ]] && [[ "${SWAP_TYPE:-file}" != "none" ]] && _has_package power-profiles-daemon; then
    mkdir -p /etc/systemd/system
    ln -sf /usr/lib/systemd/system/systemd-suspend-then-hibernate.service \
        /etc/systemd/system/systemd-suspend.service
    success "Symlinked systemd-suspend.service → systemd-suspend-then-hibernate.service for GNOME."

    cat > /etc/dconf/db/local.d/03-power <<'EOF'
[org/gnome/desktop/session]
# Blank screen after 5 minutes (300 s) of inactivity
idle-delay=uint32 300

[org/gnome/settings-daemon/plugins/power]
# Do not dim the screen before blanking
idle-dim=false
# Battery: suspend after 15 minutes (900 s) of inactivity.
# Note: this is the idle-to-sleep delay, independent of HibernateDelaySec
# (the sleep-to-hibernate delay set in sleep.conf.d/hibernate-delay.conf).
sleep-inactive-battery-timeout=900
sleep-inactive-battery-type='suspend'
# AC: never auto-suspend
sleep-inactive-ac-timeout=0
sleep-inactive-ac-type='nothing'
EOF
    success "GNOME power settings written to /etc/dconf/db/local.d/03-power."
fi

# 4. Compile dconf databases
dconf update

# 5. Hide noisy utility entries from the app menu
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
