#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# This script sets the preferences
###############################################################################

# Loop through each system directory
for system_path in "$IGNITION_SYSTEM"/*; do
  if [[ -d "$system_path" ]]; then
    export IGNITION_ACTIVE_SYSTEM="$system_path"
    system_name=$(basename "$system_path")
    echo -e "$IGNITION_TASK Configuring preferences for $system_name"
    bash "$IGNITION_ACTIVE_SYSTEM/job/configure_preferences.sh"
    echo -e "$IGNITION_DONE $system_name preferences configured"
  fi
done