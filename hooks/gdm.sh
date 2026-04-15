#!/usr/bin/env bash
# Hook: gdm
# Enables the GNOME Display Manager (login screen / session launcher) and
# configures it:
#   - No distribution logo on the login screen (dconf)
#   - No OS/Distribution logo in the active Plymouth boot splash theme
#
# Ref: https://wiki.archlinux.org/title/GDM#Installation

systemctl enable gdm

# ---------------------------------------------------------------------------
# 1. GDM dconf — logo removal
# ---------------------------------------------------------------------------
if [[ ! -f /etc/dconf/profile/gdm ]]; then
    cat > /etc/dconf/profile/gdm <<'EOF'
user-db:user
system-db:gdm
file-db:/usr/share/gdm/greeter-dconf-defaults
EOF
fi

mkdir -p /etc/dconf/db/gdm.d
cat > /etc/dconf/db/gdm.d/00-login-screen <<'EOF'
[org/gnome/login-screen]
logo=''
EOF

dconf update

# ---------------------------------------------------------------------------
# 2. Plymouth theme — remove OS/Distribution logo
# ---------------------------------------------------------------------------
# Locate the active Plymouth theme directory and remove the distribution logo
# (watermark.png or logo.png) while leaving the OEM firmware logo intact.
_plymouth_theme=$(plymouth-set-default-theme 2>/dev/null || true)
_theme_dir="/usr/share/plymouth/themes/${_plymouth_theme}"

if [[ -n "${_plymouth_theme}" && -d "${_theme_dir}" ]]; then
    for _logo in watermark.png logo.png; do
        if [[ -f "${_theme_dir}/${_logo}" ]]; then
            rm -f "${_theme_dir}/${_logo}"
        fi
    done
    unset _logo
fi

unset _plymouth_theme _theme_dir
