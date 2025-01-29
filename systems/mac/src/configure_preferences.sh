#!/usr/bin/env bash

###############################################################################
# This script sets system preferences
#
# Made by Gergely Marosi - https://github.com/marosige
###############################################################################

# Run all the preferences scripts
for script in "$IGNITION_OS"/preferences/*.sh; do
  # Get the name of the preference script
  file_name=$(basename "$script" .sh)
  
  echo -e "$IGNITION_TASK Setting $file_name preferences"
  bash "$script"
done
