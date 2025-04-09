#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# Install Packages
###############################################################################

echo -e "$IGNITION_TASK Installing Packages..."
