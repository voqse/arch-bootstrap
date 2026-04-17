#!/usr/bin/env bash
# Module 03 — Mirror selection
# Uses reflector to rank mirrors by speed, or applies a user-defined list.
# Ref: https://wiki.archlinux.org/title/Installation_guide#Select_the_mirrors

section "Mirror selection"

if declare -p MIRRORS &>/dev/null && [[ ${#MIRRORS[@]} -gt 0 ]]; then
    info "Applying mirrors from config..."
    printf 'Server = %s\n' "${MIRRORS[@]}" > /etc/pacman.d/mirrorlist
    success "Mirrorlist updated from config."
    return
fi

if command -v reflector &>/dev/null; then
    _reflector_args=(
        --save /etc/pacman.d/mirrorlist
        --protocol https
        --latest 20
        --sort rate
    )
    if [[ -n "${MIRROR_COUNTRY:-}" ]]; then
        _reflector_args+=(--country "${MIRROR_COUNTRY}")
    fi
    info "Running reflector to select fastest mirrors..."
    run reflector "${_reflector_args[@]}"
    success "Mirrorlist updated via reflector."
else
    warn "reflector not found; keeping default mirrorlist."
fi
