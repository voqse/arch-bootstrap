#!/usr/bin/env bash
# Hook: fwupd
# Enables the fwupd-refresh timer so that LVFS firmware metadata is refreshed
# automatically. Without it, users must run `fwupdmgr refresh` manually before
# checking for firmware updates.
# Ref: https://wiki.archlinux.org/title/Fwupd
systemctl enable fwupd-refresh.timer
