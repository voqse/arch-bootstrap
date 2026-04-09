#!/usr/bin/env bash
# =============================================================================
# arch-bootstrap — Modular Arch Linux installation script
#
# Usage:
#   bash bootstrap.sh [--config /path/to/preset.conf] [--help]
#
# Run from the Arch ISO live environment:
#   bash <(curl -fsSL https://raw.githubusercontent.com/voqse/arch-bootstrap/main/bootstrap.sh)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
CONFIG_FILE="${SCRIPT_DIR}/config/default.conf"

_usage() {
    cat <<EOF
Usage: ${0##*/} [OPTIONS]

Modular Arch Linux installation script.

Options:
  --config FILE   Path to a configuration preset file.
                  (default: config/default.conf next to this script)
  --help          Show this help message and exit.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --config)
            CONFIG_FILE="${2:?--config requires a file path}"
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

# ---------------------------------------------------------------------------
# Bootstrap
# ---------------------------------------------------------------------------

# Load shared library
# shellcheck source=lib.sh
source "${SCRIPT_DIR}/lib.sh"

require_root

if [[ ! -f "${CONFIG_FILE}" ]]; then
    die "Config file not found: ${CONFIG_FILE}"
fi

info "Loading config: ${CONFIG_FILE}"
# shellcheck source=/dev/null
source "${CONFIG_FILE}"

# Load all pre-chroot modules in alphabetical order
for module in "${SCRIPT_DIR}/modules"/[0-9]*.sh; do
    # shellcheck source=/dev/null
    source "${module}"
done

# ---------------------------------------------------------------------------
# Run installation pipeline
# ---------------------------------------------------------------------------

section "arch-bootstrap — Arch Linux installation"
info "Config: ${CONFIG_FILE}"

module_pre_checks
module_disk
module_mirrors
module_pacstrap
module_fstab
module_chroot

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
section "Installation complete"
echo
success "Arch Linux has been installed successfully!"
echo
info "Next steps:"
echo "  1. Review the output above for any warnings."
echo "  2. Unmount partitions:  umount -R /mnt"
echo "  3. Remove the installation medium and reboot:  reboot"
echo
