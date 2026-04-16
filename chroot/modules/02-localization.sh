#!/usr/bin/env bash
# =============================================================================
# Chroot module — Localization
# Ref: https://wiki.archlinux.org/title/Installation_guide#Localization
# =============================================================================

section "Localization"

# Uncomment requested locales in /etc/locale.gen
for locale in "${LOCALES[@]}"; do
    # locale entry looks like: #en_US.UTF-8 UTF-8
    _locale_name="${locale%% *}"           # the locale name part
    # Handle both "en_US.UTF-8" and "en_US.UTF-8 UTF-8" forms
    if grep -q "^#${_locale_name}" /etc/locale.gen; then
        sed -i "s/^#\(${_locale_name}.*\)/\1/" /etc/locale.gen
        info "Enabled locale: ${_locale_name}"
    elif grep -q "^${_locale_name}" /etc/locale.gen; then
        info "Locale already enabled: ${_locale_name}"
    else
        warn "Locale not found in /etc/locale.gen: ${_locale_name}"
    fi
done

run locale-gen

# /etc/locale.conf
echo "LANG=${LANG}" > /etc/locale.conf
success "LANG=${LANG} written to /etc/locale.conf."

# /etc/vconsole.conf — authoritative write; overwrites the minimal fallback
# that was created by the pacstrap module before package installation.
{
    echo "KEYMAP=${KEYMAP}"
    echo "FONT=${FONT}"
    # GDM (and Xorg/Wayland sessions) use XKBLAYOUT, not KEYMAP.
    # Ref: https://wiki.archlinux.org/title/GDM#Keyboard_layout
    [[ -n "${XKBLAYOUT:-}" ]] && echo "XKBLAYOUT=${XKBLAYOUT}"
    [[ -n "${XKBOPTIONS:-}" ]] && echo "XKBOPTIONS=${XKBOPTIONS}"
} > /etc/vconsole.conf
success "vconsole.conf: KEYMAP=${KEYMAP}, FONT=${FONT}${XKBLAYOUT:+, XKBLAYOUT=${XKBLAYOUT}}."
