#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# This script sets system preferences
###############################################################################

# Run all preference scripts in the preferences folder
lib_run_scripts_in_folder "$IGNITION_ACTIVE_SYSTEM/preferences"