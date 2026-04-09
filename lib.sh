#!/usr/bin/env bash
# =============================================================================
# lib.sh — shared helper functions used across all modules
# =============================================================================

# Colours
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }
die()     { error "$*"; exit 1; }

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

# Pretty section header
section() {
    echo
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${BOLD}${CYAN}  $*${RESET}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo
}
