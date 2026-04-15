#!/usr/bin/env bash
# =============================================================================
# Chroot module — Localization
# Ref: https://wiki.archlinux.org/title/Installation_guide#Localization
# =============================================================================

chroot_localization() {
    section "Localization"

    # Uncomment requested locales in /etc/locale.gen
    for locale in "${LOCALES[@]}"; do
        # locale entry looks like: #en_US.UTF-8 UTF-8
        local charset="${locale##* }"        # everything after a space (may be absent)
        local name="${locale%% *}"           # the locale name part
        # Handle both "en_US.UTF-8" and "en_US.UTF-8 UTF-8" forms
        if grep -q "^#${name}" /etc/locale.gen; then
            sed -i "s/^#\(${name}.*\)/\1/" /etc/locale.gen
            info "Enabled locale: ${name}"
        elif grep -q "^${name}" /etc/locale.gen; then
            info "Locale already enabled: ${name}"
        else
            warn "Locale not found in /etc/locale.gen: ${name}"
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
}
