#!/usr/bin/env bash
# Hook: nvm
# Adds the NVM initialisation line to the install user's shell profile files
# so that nvm is available in interactive and login shells.
# The AUR nvm package installs to /usr/share/nvm and provides init-nvm.sh
# (sets NVM_DIR, sources nvm.sh and bash_completion); the upstream
# ~/.nvm/nvm.sh path from the official installer does not exist here.
# Ref: https://wiki.archlinux.org/title/Node.js#nvm

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${HOOK_DIR}/../config.sh"

[[ -n "${INSTALL_USERNAME:-}" ]] || exit 0

_user_home="/home/${INSTALL_USERNAME}"

_nvm_init='source /usr/share/nvm/init-nvm.sh'

_add_nvm_to_profile() {
    local profile_file="$1"
    # Skip if NVM initialisation is already present in this file
    grep -qE 'init-nvm\.sh|NVM_DIR' "${profile_file}" 2>/dev/null && return 0
    printf '\n%s\n' "${_nvm_init}" >> "${profile_file}"
}

# Attempt to add to each profile file that already exists
_added=0
for _profile in \
    "${_user_home}/.bashrc" \
    "${_user_home}/.bash_profile" \
    "${_user_home}/.zshrc" \
    "${_user_home}/.profile"
do
    if [[ -f "${_profile}" ]]; then
        _add_nvm_to_profile "${_profile}"
        _added=$((_added + 1))
    fi
done

# Fall back to creating ~/.bash_profile if no profile files exist yet.
# Also source ~/.bashrc so that interactive non-login shells (e.g. terminal
# emulators) pick up the nvm initialisation via the login profile.
if (( _added == 0 )); then
    printf '[[ -f ~/.bashrc ]] && . ~/.bashrc\n\n%s\n' \
        "${_nvm_init}" > "${_user_home}/.bash_profile"
    chown "${INSTALL_USERNAME}": "${_user_home}/.bash_profile"
fi
