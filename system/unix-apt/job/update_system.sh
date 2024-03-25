#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Update system
###############################################################################

echo -e "$IGNITION_TASK Updating system..."
sudo apt update
sudo apt upgrade -y
