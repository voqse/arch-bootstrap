#!/usr/bin/env bash
# Hook: tlp-pd
# Enables the tlp-pd compatibility service for desktop power profiles.
# Ref: https://wiki.archlinux.org/title/TLP
systemctl enable tlp-pd.service || \
    echo "Warning: failed to enable tlp-pd.service." >&2
