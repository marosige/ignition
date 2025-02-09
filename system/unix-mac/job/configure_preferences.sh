#!/usr/bin/env bash

###############################################################################
# This script sets system preferences
###############################################################################

# Run all preference scripts in the preferences folder

echo "$IGNITION_INDENT Configuring system preferences..."

lib_run_scripts_in_folder "$IGNITION_ACTIVE_SYSTEM/preferences"

echo "$IGNITION_DONE System preferences configured"