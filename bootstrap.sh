#!/usr/bin/env bash
# arch-bootstrap — Modular Arch Linux installation script
#
# Usage:
#   bash bootstrap.sh [--config /path/to/preset.conf] [--help]
#
# Run from the Arch ISO live environment:
#   bash <(curl -fsSL https://raw.githubusercontent.com/voqse/arch-bootstrap/master/bootstrap.sh)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Self-bootstrap: when run via "bash <(curl ...)" the script is fed through a
# file-descriptor, so SCRIPT_DIR resolves to /dev/fd or similar and sibling
# files (lib.sh, modules/) are absent.  Download the repository archive into
# a temp directory and re-execute from there so that all relative paths work
# correctly.  curl is used instead of git because git may be unavailable in
# the live environment (e.g., Arch ISO).
_REPO_URL="https://github.com/voqse/arch-bootstrap"
_REPO_BRANCH="master"
_CLONE_DIR="/tmp/arch-bootstrap"

if [[ ! -f "${SCRIPT_DIR}/lib.sh" || ! -d "${SCRIPT_DIR}/modules" ]]; then
    echo "==> Sibling files not found — downloading ${_REPO_URL} into ${_CLONE_DIR} ..."
    rm -rf "${_CLONE_DIR}"
    mkdir -p "${_CLONE_DIR}"
    curl -fsSL "${_REPO_URL}/archive/refs/heads/${_REPO_BRANCH}.tar.gz" \
        | tar -xzf - --strip-components=1 -C "${_CLONE_DIR}"
    exec bash "${_CLONE_DIR}/bootstrap.sh" "$@"
fi

# Argument parsing
CONFIG_FILE="${SCRIPT_DIR}/config/default.conf"
_PRESET_NAME=""
_CONFIG_EXPLICIT=false

_usage() {
    cat <<EOF
Usage: ${0##*/} [OPTIONS]

Modular Arch Linux installation script.

Options:
  --preset NAME   Name of a built-in preset from config/<NAME>.conf.
                  Works when running via "bash <(curl ...)" — the repo is
                  cloned automatically and the preset is resolved from it.
  --config FILE   Path to a configuration preset file.
                  (default: config/default.conf next to this script)
  --help          Show this help message and exit.

Only one of --preset or --config may be specified at a time.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --preset)
            _PRESET_NAME="${2:?--preset requires a preset name}"
            shift 2
            ;;
        --config)
            CONFIG_FILE="${2:?--config requires a file path}"
            _CONFIG_EXPLICIT=true
            shift 2
            ;;
        --help|-h)
            _usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            _usage
            exit 1
            ;;
    esac
done

if [[ -n "${_PRESET_NAME}" && "${_CONFIG_EXPLICIT}" == true ]]; then
    echo "--preset and --config are mutually exclusive." >&2
    _usage
    exit 1
fi

if [[ -n "${_PRESET_NAME}" ]]; then
    if [[ ! "${_PRESET_NAME}" =~ ^[A-Za-z0-9_-]+$ ]]; then
        echo "--preset name must contain only letters, digits, hyphens, or underscores." >&2
        exit 1
    fi
    CONFIG_FILE="${SCRIPT_DIR}/config/${_PRESET_NAME}.conf"
fi

# Bootstrap

# Load shared library
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_root

_DEFAULT_CONF="${SCRIPT_DIR}/config/default.conf"

if [[ ! -f "${CONFIG_FILE}" ]]; then
    die "Config file not found: ${CONFIG_FILE}"
fi

# Always source defaults first so preset files only need to override what they change.
# shellcheck source=config/default.conf
source "${_DEFAULT_CONF}"

if [[ "${CONFIG_FILE}" != "${_DEFAULT_CONF}" ]]; then
    info "Loading preset: ${CONFIG_FILE}"
    # shellcheck source=/dev/null
    source "${CONFIG_FILE}"
fi

# Pre-flight checks — run before any interactive prompts

section "Pre-flight checks"

# 1. Confirm selected preset
if [[ "${CONFIG_FILE}" != "${_DEFAULT_CONF}" ]]; then
    info "Preset: ${CONFIG_FILE}"
else
    info "Preset: default (${CONFIG_FILE})"
fi
ask_yn "Continue with this configuration?" "y" || exit 0

# 2. Validate preset swap configuration when already set by a preset
if [[ -n "${SWAP_TYPE:-}" ]]; then
    case "${SWAP_TYPE,,}" in
        file|partition|none) SWAP_TYPE="${SWAP_TYPE,,}" ;;
        *)
            die "Invalid SWAP_TYPE in preset/config: '${SWAP_TYPE}'. Expected: file, partition, or none."
            ;;
    esac

    if [[ "${SWAP_TYPE}" != "none" ]]; then
        if [[ -z "${SWAP_SIZE:-}" ]]; then
            die "SWAP_SIZE must be set in preset/config when SWAP_TYPE is '${SWAP_TYPE}'. Enter a positive integer followed by M or G (e.g. 4096M or 16G)."
        fi
        if [[ ! "${SWAP_SIZE}" =~ ^[1-9][0-9]*[MmGg]$ ]]; then
            die "Invalid SWAP_SIZE in preset/config: '${SWAP_SIZE}'. Enter a positive integer followed by M or G (e.g. 4096M or 16G)."
        fi
        SWAP_SIZE="${SWAP_SIZE^^}"
        info "Swap configuration from preset: type=${SWAP_TYPE}, size=${SWAP_SIZE}"
    else
        info "Swap configuration from preset: type=${SWAP_TYPE}"
    fi
fi

# 3. Detect timezone via IP geolocation — only on the live ISO
# (when run via "bash <(curl ...)" the script re-executes from _CLONE_DIR).
_detected_tz="UTC"
if [[ "${SCRIPT_DIR}" == "${_CLONE_DIR}" ]]; then
    _tz_candidate=""
    if _tz_candidate=$(curl -fsSL --max-time 5 "https://ipapi.co/timezone" 2>/dev/null) \
            && [[ -f "/usr/share/zoneinfo/${_tz_candidate}" ]]; then
        _detected_tz="${_tz_candidate}"
        info "Detected timezone: ${_detected_tz}"
    fi
fi

# Collect user credentials (always interactive, independent of preset)

section "User credentials"

ask_value "Username" "user"
INSTALL_USERNAME="${REPLY}"

ask_password "Password for '${INSTALL_USERNAME}'"
INSTALL_USER_PASSWORD="${REPLY}"

info "Root password — leave empty to lock the root account."
ask_password "Root password" true
ROOT_PASSWORD="${REPLY}"

ask_value "Hostname" "${HOSTNAME}"
HOSTNAME="${REPLY}"

# Timezone is not a preset value — it must always be chosen at install time.
while true; do
    ask_value "Timezone" "${TIMEZONE:-${_detected_tz}}"
    if [[ -f "/usr/share/zoneinfo/${REPLY}" ]]; then
        TIMEZONE="${REPLY}"
        break
    fi
    warn "Unknown timezone '${REPLY}'. Check /usr/share/zoneinfo/ for valid entries."
done

# Swap type and size — prompt only when not already set by a preset
if [[ -z "${SWAP_TYPE:-}" ]]; then
    while true; do
        ask_value "Swap type (file, partition, none)" "file"
        case "${REPLY,,}" in
            file|partition|none) SWAP_TYPE="${REPLY,,}"; break ;;
            *) warn "Invalid swap type. Enter: file, partition, or none." ;;
        esac
    done

    if [[ "${SWAP_TYPE}" != "none" ]]; then
        while true; do
            ask_value "Swap size"
            if [[ "${REPLY}" =~ ^[1-9][0-9]*[MmGg]$ ]]; then
                SWAP_SIZE="${REPLY^^}"
                break
            fi
            warn "Invalid swap size. Enter a positive integer followed by M or G (e.g. 4096M or 16G)."
        done
    fi
fi

# Run installation pipeline

section "arch-bootstrap — Arch Linux installation"
info "Config: ${CONFIG_FILE}"

shopt -s nullglob
modules=("${SCRIPT_DIR}/modules"/[0-9]*.sh)
shopt -u nullglob
[[ ${#modules[@]} -eq 0 ]] && die "No modules found in ${SCRIPT_DIR}/modules/"

for module in "${modules[@]}"; do
    # shellcheck source=/dev/null
    source "${module}"
done

# Done
section "Installation complete"
echo
success "Arch Linux has been installed successfully!"
echo
info "Next steps:"
echo "  1. Review the output above for any warnings."
echo "  2. Unmount partitions:  umount -R /mnt"
echo "  3. Remove the installation medium and reboot:  reboot"
echo
