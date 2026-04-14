#!/usr/bin/env bash
# Hook: ufw
# Installs default UFW policy (deny incoming, allow outgoing) and enables UFW.
ufw default deny incoming
ufw default allow outgoing
ufw --force enable
