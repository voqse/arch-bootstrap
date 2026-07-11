#!/usr/bin/env bash
# Module 03 — Mirror selection
# Uses reflector to rank mirrors by speed, or applies a user-defined list.
# Reflector arguments come from REFLECTOR_ARGS in the preset config — the
# same set that hooks/reflector.sh later writes to the installed system
# (single source of truth).
# Ref: https://wiki.archlinux.org/title/Installation_guide#Select_the_mirrors

section "Mirror selection"

if declare -p MIRRORS &>/dev/null && [[ ${#MIRRORS[@]} -gt 0 ]]; then
    info "Applying mirrors from config..."
    printf 'Server = %s\n' "${MIRRORS[@]}" > /etc/pacman.d/mirrorlist
    success "Mirrorlist updated from config."
    return
fi

if command -v reflector &>/dev/null; then
    _reflector_args=(--save /etc/pacman.d/mirrorlist)
    if declare -p REFLECTOR_ARGS &>/dev/null; then
        # Each element holds "--flag value"; split into tokens for execution.
        for _reflector_line in "${REFLECTOR_ARGS[@]}"; do
            read -ra _reflector_tokens <<< "${_reflector_line}"
            _reflector_args+=("${_reflector_tokens[@]}")
        done
    fi
    info "Running reflector to select fastest mirrors..."
    run reflector "${_reflector_args[@]}"
    success "Mirrorlist updated via reflector."
else
    warn "reflector not found; keeping default mirrorlist."
fi
