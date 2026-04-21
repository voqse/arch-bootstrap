#!/usr/bin/env bash
# Chroot module — Per-package post-install hooks
# Reads the PACKAGES array from config; entries of the form "pkg:hook_name"
# will execute hooks/<hook_name>.sh inside the chroot.

section "Package post-install hooks"

_hooks_chroot_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run_hooks "${_hooks_chroot_dir}/hooks" "package" "${PACKAGES[@]+"${PACKAGES[@]}"}"
