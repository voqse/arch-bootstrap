#!/usr/bin/env bash
# Hook: gnome-shell
# Configures GNOME Shell via system-wide dconf overrides:
#   - Solid #0e1722 desktop background for user sessions (app grid and
#     workspace overview inherit this colour)
#   - Solid #152131 top panel via a minimal system-level shell extension
#   - Enables AppIndicator tray icon extension
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
primary-color='#0e1722'
color-shading-type='solid'
picture-uri=''
picture-uri-dark=''
EOF

cat > /etc/dconf/db/local.d/01-extensions <<'EOF'
[org/gnome/shell]
# Fresh-install bootstrap: no prior extensions exist, so a full assignment is safe here.
enabled-extensions=['appindicatorsupport@rgcjonas.gmail.com', 'panel-color@arch-bootstrap']
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
# 2. GNOME Shell panel colour override — minimal system extension
# ---------------------------------------------------------------------------
# Install a tiny extension that injects a single CSS rule to paint the top
# panel with the desired background colour.  Extensions placed in
# /usr/share/gnome-shell/extensions/ are available system-wide and are
# activated by the dconf key set in 01-extensions above.
_ext_dir="/usr/share/gnome-shell/extensions/panel-color@arch-bootstrap"
mkdir -p "${_ext_dir}"

cat > "${_ext_dir}/metadata.json" <<'EOF'
{
  "uuid": "panel-color@arch-bootstrap",
  "name": "Panel Color",
  "description": "System-level top-panel background colour override.",
  "shell-version": ["45", "46", "47", "48"],
  "version": 1
}
EOF

cat > "${_ext_dir}/extension.js" <<'EOF'
import { Extension } from 'resource:///org/gnome/shell/extensions/extension.js';

export default class PanelColorExtension extends Extension {
    // GNOME Shell automatically loads stylesheet.css from the extension
    // directory when the extension is enabled, so no JS logic is needed.
    enable() {}
    disable() {}
}
EOF

cat > "${_ext_dir}/stylesheet.css" <<'EOF'
/* Override top-panel background colour */
#panel {
    background-color: #152131;
}
EOF

unset _ext_dir

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
