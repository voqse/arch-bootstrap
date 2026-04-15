#!/usr/bin/env bash
# =============================================================================
# lib.sh — shared helper functions used across all modules
# =============================================================================

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "  ${BOLD}>${RESET} $*"; }
success() { echo -e "  ${GREEN}✓${RESET} $*"; }
warn()    { echo -e "  ${YELLOW}!${RESET} $*" >&2; }
error()   { echo -e "  ${RED}✗${RESET} $*" >&2; }
die()     { error "$*"; exit 1; }

# Ask for a password (hidden input), confirmed by a second prompt.
# Usage: ask_password "Prompt" [allow_empty=false]
# Result is stored in REPLY.
ask_password() {
    local prompt="$1"
    local allow_empty="${2:-false}"
    local password confirm

    while true; do
        read -rsp "$(echo -e "${BOLD}${prompt}: ${RESET}")" password
        echo
        if [[ -z "${password}" ]]; then
            if [[ "${allow_empty}" == "true" ]]; then
                REPLY=""
                return 0
            fi
            warn "Password cannot be empty. Please try again."
            continue
        fi
        read -rsp "$(echo -e "${BOLD}Confirm password: ${RESET}")" confirm
        echo
        if [[ "${password}" == "${confirm}" ]]; then
            REPLY="${password}"
            return 0
        fi
        warn "Passwords do not match. Please try again."
    done
}

# Ask yes/no question; returns 0 for yes, 1 for no.
# Usage: ask_yn "Question?" [default_yes]
ask_yn() {
    local prompt="$1"
    local default="${2:-}"
    local reply

    if [[ "$default" == "y" ]]; then
        prompt+=" [Y/n] "
    else
        prompt+=" [y/N] "
    fi

    while true; do
        read -r -p "$(echo -e "${BOLD}${prompt}${RESET}")" reply
        reply="${reply:-$default}"
        case "${reply,,}" in
            y|yes) return 0 ;;
            n|no)  return 1 ;;
            *)     warn "Please answer yes or no." ;;
        esac
    done
}

# Ask for a value with an optional default.
# Usage: ask_value "Prompt" [default]
# Result is stored in REPLY.
ask_value() {
    local prompt="$1"
    local default="${2:-}"

    if [[ -n "$default" ]]; then
        prompt+=" [${default}]"
    fi
    prompt+=": "

    read -r -p "$(echo -e "${BOLD}${prompt}${RESET}")" REPLY
    REPLY="${REPLY:-$default}"
}

# Run a command, print it first, and die on failure.
run() {
    info "Running: $*"
    "$@" || die "Command failed: $*"
}

# Run a command silently, die on failure.
run_quiet() {
    "$@" || die "Command failed: $*"
}

# Check that we are running as root.
require_root() {
    [[ $EUID -eq 0 ]] || die "This script must be run as root."
}

# Check that a variable is non-empty.
require_var() {
    local name="$1"
    [[ -n "${!name}" ]] || die "Required variable \$${name} is not set."
}

# Return 0 if the package named $1 is present in any installed package array.
# Handles both plain "pkg" and "pkg:hook" entries.
_has_package() {
    local name="$1" entry pkg
    for entry in \
        "${PACKAGES[@]+"${PACKAGES[@]}"}" \
        "${BASE_PACKAGES[@]+"${BASE_PACKAGES[@]}"}"; do
        pkg="${entry%%:*}"
        [[ "${pkg}" == "${name}" ]] && return 0
    done
    return 1
}

# Section header
section() {
    echo
    echo -e "${BOLD}==> $*${RESET}"
    echo
}

# =============================================================================
# mkinitcpio helpers
# All functions operate on /etc/mkinitcpio.conf by default.
# Override by setting MKINITCPIO_CONF before sourcing this file.
# =============================================================================
MKINITCPIO_CONF="${MKINITCPIO_CONF:-/etc/mkinitcpio.conf}"

# Return 0 if module $1 is present in MODULES=(...).
mkinitcpio_has_module() {
    local mod="$1" current
    current=$(sed -n 's/^MODULES=(\(.*\))/\1/p' "${MKINITCPIO_CONF}" | tr -s ' ')
    echo " ${current} " | grep -qw "${mod}"
}

# Add one or more modules to MODULES=(...).
# Silently skips modules already present.
# Returns 1 (with a warning) if mkinitcpio.conf does not exist.
mkinitcpio_add_modules() {
    if [[ ! -f "${MKINITCPIO_CONF}" ]]; then
        warn "mkinitcpio_add_modules: ${MKINITCPIO_CONF} not found."
        return 1
    fi
    local current changed=false
    current=$(sed -n 's/^MODULES=(\(.*\))/\1/p' "${MKINITCPIO_CONF}" | tr -s ' ' | sed 's/^ //;s/ $//')
    for mod in "$@"; do
        if ! echo " ${current} " | grep -qw "${mod}"; then
            current="${current:+${current} }${mod}"
            changed=true
            info "mkinitcpio: added module '${mod}'."
        fi
    done
    if [[ "${changed}" == true ]]; then
        if grep -q '^MODULES=(' "${MKINITCPIO_CONF}"; then
            sed -i -E "s|^MODULES=\(.*\)|MODULES=(${current})|" "${MKINITCPIO_CONF}"
        else
            echo "MODULES=(${current})" >> "${MKINITCPIO_CONF}"
        fi
    fi
}

# Return 0 if hook $1 is present in HOOKS=(...).
mkinitcpio_has_hook() {
    local hook="$1"
    grep -qE "^HOOKS=\([^)]*([[:space:]]|\()${hook}([[:space:]]|\))[^)]*\)" "${MKINITCPIO_CONF}" 2>/dev/null
}

# Echo the zero-based index of hook $1 in HOOKS=(...), or -1 if absent.
mkinitcpio_hook_index() {
    local hook_name="$1" hooks_line hooks_body
    local -a hooks
    local i
    hooks_line=$(grep -m1 '^HOOKS=(' "${MKINITCPIO_CONF}" 2>/dev/null || true)
    if [[ -z "${hooks_line}" ]]; then echo -1; return 0; fi
    hooks_body="${hooks_line#HOOKS=(}"
    hooks_body="${hooks_body%)}"
    read -r -a hooks <<< "${hooks_body}"
    for i in "${!hooks[@]}"; do
        [[ "${hooks[i]}" == "${hook_name}" ]] && echo "${i}" && return 0
    done
    echo -1
}

# Insert <new_hook> immediately after <anchor_hook> in HOOKS=(...).
# No-op if <new_hook> is already present.
# Returns 1 (with a warning) if mkinitcpio.conf is missing or anchor not found.
mkinitcpio_add_hook_after() {
    local new_hook="$1" anchor="$2"
    if [[ ! -f "${MKINITCPIO_CONF}" ]]; then
        warn "mkinitcpio_add_hook_after: ${MKINITCPIO_CONF} not found."
        return 1
    fi
    mkinitcpio_has_hook "${new_hook}" && return 0
    if ! mkinitcpio_has_hook "${anchor}"; then
        warn "mkinitcpio_add_hook_after: anchor hook '${anchor}' not found in HOOKS."
        return 1
    fi
    sed -E -i "/^HOOKS=/s/([[:space:](])${anchor}([[:space:])])/\1${anchor} ${new_hook}\2/" "${MKINITCPIO_CONF}" \
        || { warn "mkinitcpio_add_hook_after: sed failed to update HOOKS in ${MKINITCPIO_CONF}."; return 1; }
    info "mkinitcpio: added hook '${new_hook}' after '${anchor}'."
}

# Insert <new_hook> immediately before <anchor_hook> in HOOKS=(...).
# No-op if <new_hook> is already present.
# Returns 1 (with a warning) if mkinitcpio.conf is missing or anchor not found.
mkinitcpio_add_hook_before() {
    local new_hook="$1" anchor="$2"
    if [[ ! -f "${MKINITCPIO_CONF}" ]]; then
        warn "mkinitcpio_add_hook_before: ${MKINITCPIO_CONF} not found."
        return 1
    fi
    mkinitcpio_has_hook "${new_hook}" && return 0
    if ! mkinitcpio_has_hook "${anchor}"; then
        warn "mkinitcpio_add_hook_before: anchor hook '${anchor}' not found in HOOKS."
        return 1
    fi
    sed -E -i "/^HOOKS=/s/([[:space:](])${anchor}([[:space:])])/\1${new_hook} ${anchor}\2/" "${MKINITCPIO_CONF}" \
        || { warn "mkinitcpio_add_hook_before: sed failed to update HOOKS in ${MKINITCPIO_CONF}."; return 1; }
    info "mkinitcpio: added hook '${new_hook}' before '${anchor}'."
}
