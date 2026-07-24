#!/usr/bin/env bash
# Hook: neovim
# The fleet uses neovim as its only vi-family editor; the vim package is
# deliberately not installed. Symlink vim to nvim in /usr/local/bin (PATH
# precedence, and no clash with pacman-owned /usr/bin if a vim package ever
# appears) so tools that hardcode `vim` keep working.

ln -sf /usr/bin/nvim /usr/local/bin/vim
