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

# Return 0 if the package named $1 is present in the PACKAGES array.
# Handles both plain "pkg" and "pkg:hook" entries.
_has_package() {
    local name="$1" entry pkg
    for entry in "${PACKAGES[@]+"${PACKAGES[@]}"}"; do
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
