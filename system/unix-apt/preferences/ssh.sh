#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Configuring SSH
###############################################################################

echo "Enabling and starting OpenSSH..."
systemctl enable --now ssh
