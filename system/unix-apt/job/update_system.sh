#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Update system
###############################################################################

echo "Updating system..."
apt update && apt upgrade -y
