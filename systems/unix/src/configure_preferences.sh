#!/usr/bin/env bash

###############################################################################
# This script sets system preferences
#
# Made by Gergely Marosi - https://github.com/marosige
###############################################################################

set_preferences() {
  # Run all the preferences scripts
  for script in "$1"/preferences/*.sh; do
    # Get the name of the preference script
    file_name=$(basename "$script" .sh)
    
    # Skip files that start with a dot
    if [[ "$file_name" == .* ]]; then
      continue
    fi
    
    echo -e "$IGNITION_TASK Setting $file_name preferences"
    bash "$script"
  done
}

# Call the function for both IGNITION_UNIX and IGNITION_OS
set_preferences "$IGNITION_UNIX"
set_preferences "$IGNITION_OS"
