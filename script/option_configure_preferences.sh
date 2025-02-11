#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# This script sets the preferences
###############################################################################

# Loop through each system directory
for system_path in "$IGNITION_SYSTEM"/*; do
  if [[ -d "$system_path" ]]; then
    bash "$IGNITION_ACTIVE_SYSTEM/job/configure_preferences.sh"
  fi
done