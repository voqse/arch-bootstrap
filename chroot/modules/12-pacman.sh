#!/usr/bin/env bash
# Chroot module — pacman.conf options
# Color and VerbosePkgLists are stock-commented cosmetics: colored output
# (inherited by yay) and a name/old/new/size table on -Syu instead of a
# one-line package list. ParallelDownloads is raised from the shipped 5 to
# 10: parallelism only spans different packages (a single package is always
# one connection to one mirror), so with individually slow mirrors more
# streams raise the aggregate -Syu rate.
# Ref: https://wiki.archlinux.org/title/Pacman#Enabling_parallel_downloads

section "pacman.conf options"

sed -i \
    -e 's/^#Color$/Color/' \
    -e 's/^#VerbosePkgLists$/VerbosePkgLists/' \
    -e 's/^#\?ParallelDownloads.*/ParallelDownloads = 10/' \
    /etc/pacman.conf

success "Enabled Color, VerbosePkgLists, ParallelDownloads = 10."
