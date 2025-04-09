#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# Directory Structure
###############################################################################

echo -e "$IGNITION_TASK Creating Directories..."

mkdir_withlog -p ~/example/directory/structure  # Description of the directory
