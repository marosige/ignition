#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# Directory Structure
###############################################################################

mkdir_withlog ~/bin     # For installed scripts
mkdir_withlog ~/tmp     # For temporarly files
