#!/usr/bin/env bash
# Hook: nvm
# Adds NVM source lines to the install user's shell profile files so that
# nvm is available in interactive and login shells.
# Follows the profile-detection logic from the official nvm installer:
# Ref: https://github.com/nvm-sh/nvm

HOOK_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=/dev/null
source "${HOOK_DIR}/../config.sh"

[[ -n "${INSTALL_USERNAME:-}" ]] || exit 0

_user_home="/home/${INSTALL_USERNAME}"

# The two lines to append, as recommended in the nvm documentation.
# shellcheck disable=SC2016
_nvm_source='export NVM_DIR="$([ -z "${XDG_CONFIG_HOME-}" ] && printf %s "${HOME}/.nvm" || printf %s "${XDG_CONFIG_HOME}/nvm")"'
# shellcheck disable=SC2016
_nvm_load='[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" # This loads nvm'

_add_nvm_to_profile() {
    local profile_file="$1"
    # Skip if NVM lines are already present in this file
    grep -qF 'NVM_DIR' "${profile_file}" 2>/dev/null && return 0
    printf '\n%s\n%s\n' "${_nvm_source}" "${_nvm_load}" >> "${profile_file}"
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
    printf '[[ -f ~/.bashrc ]] && . ~/.bashrc\n\n%s\n%s\n' \
        "${_nvm_source}" "${_nvm_load}" > "${_user_home}/.bash_profile"
    chown "${INSTALL_USERNAME}": "${_user_home}/.bash_profile"
fi
