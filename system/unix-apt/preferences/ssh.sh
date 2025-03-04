#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Configuring SSH
###############################################################################

echo "$IGNITION_WARN Skipping SSH setup now..."
exit 0

echo "Enabling and starting OpenSSH..."
systemctl enable --now ssh
