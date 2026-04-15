#!/usr/bin/env bash
# Hook: gdm
# Enables the GNOME Display Manager (login screen / session launcher) and
# configures it:
#   - No distribution logo on the login screen (dconf)
#   - Solid #152131 background via GNOME Shell CSS gresource patch
#
# NOTE: In GNOME 42+, the GDM login screen background is rendered entirely
# by GNOME Shell CSS (#lockDialogGroup).  The org/gnome/desktop/background
# dconf keys are not used by the GDM greeter and have no visual effect.
# The only reliable mechanism is to append an override rule to the bundled
# CSS theme and recompile the gresource file.
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
# 2. GDM background color — gresource CSS patch
# ---------------------------------------------------------------------------
# Install a helper script that extracts the bundled GNOME Shell theme,
# appends a background-color override for #lockDialogGroup, and recompiles
# the gresource in place.  The script is then run immediately and wired into
# a pacman hook so it reapplies automatically after every gnome-shell upgrade.

cat > /usr/local/bin/arch-bootstrap-gdm-color <<'SCRIPT'
#!/usr/bin/env bash
# Patches the GNOME Shell theme gresource to set the GDM login screen
# background color.  Invoked at install time and by the pacman hook after
# every gnome-shell upgrade.
set -euo pipefail

_color='#152131'
_gresource='/usr/share/gnome-shell/gnome-shell-theme.gresource'

_tmpdir=$(mktemp -d)
trap 'rm -rf "$_tmpdir"' EXIT INT TERM

# Extract every resource, preserving the full path under $_tmpdir.
# Validate each resource path to guard against directory traversal.
while IFS= read -r _res; do
    if [[ "$_res" == *..* ]]; then
        echo "arch-bootstrap-gdm-color: skipping suspicious resource path: $_res" >&2
        continue
    fi
    _dst="${_tmpdir}${_res}"
    mkdir -p "$(dirname "$_dst")"
    gresource extract "$_gresource" "$_res" > "$_dst"
done < <(gresource list "$_gresource")

# Append background-color override to the main GNOME Shell stylesheet
_css="${_tmpdir}/org/gnome/shell/theme/gnome-shell.css"
if [[ ! -f "$_css" ]]; then
    echo "arch-bootstrap-gdm-color: gnome-shell.css not found in gresource" >&2
    exit 1
fi
printf '\n/* arch-bootstrap: GDM background color */\n#lockDialogGroup { background: %s; }\n' \
    "$_color" >> "$_css"

# Generate gresource XML with paths relative to --sourcedir
_themedir="${_tmpdir}/org/gnome/shell/theme"
_xml="${_tmpdir}/gdm.gresource.xml"
{
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<gresources>'
    echo '  <gresource prefix="/org/gnome/shell/theme">'
    find "$_themedir" -type f | sort | while IFS= read -r _f; do
        echo "    <file>$(realpath --relative-to="$_themedir" "$_f")</file>"
    done
    echo '  </gresource>'
    echo '</gresources>'
} > "$_xml"

# Compile to a temporary output first; only replace the original on success
_out="${_tmpdir}/gnome-shell-theme.gresource"
glib-compile-resources \
    --sourcedir="$_themedir" \
    --target="$_out" \
    "$_xml"
mv "$_out" "$_gresource"
SCRIPT
chmod +x /usr/local/bin/arch-bootstrap-gdm-color

# Apply the patch now
/usr/local/bin/arch-bootstrap-gdm-color

# Install a pacman hook so the patch survives gnome-shell upgrades
mkdir -p /etc/pacman.d/hooks
cat > /etc/pacman.d/hooks/arch-bootstrap-gdm-color.hook <<'EOF'
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = gnome-shell

[Action]
Description = Reapplying GDM background color...
When = PostTransaction
Exec = /usr/local/bin/arch-bootstrap-gdm-color
EOF
