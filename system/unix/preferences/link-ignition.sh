#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# Link files
###############################################################################

# Link ignition to the bin directory
ln -sf "$IGNITION_DIR/ignition.sh" "$HOME/bin/ignition"
