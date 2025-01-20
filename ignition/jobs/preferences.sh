#!/usr/bin/env bash

###############################################################################
# This script sets system preferences
#
# Made by Gergely Marosi - https://github.com/marosige
###############################################################################

PREF_FOLDER="$IG_OS/preferences"

# Check if the folder exists and is not empty
if [[ ! -d "$PREF_FOLDER" || -z "$(ls -A "$PREF_FOLDER" 2>/dev/null)" ]]; then
    warn "Folder $PREF_FOLDER does not exist or is empty. Doing nothing."
    exit 1
fi

print_warning () {
  message "This script is configuring system settings and preferences."
  info "Please be aware that running this script will modify your system and may affect your existing configurations."
  message "Ensure you have reviewed the script and understand the changes it will make before proceeding: https://github.com/marosige/ignition"
  warn "IMPORTANT: Backup any important configurations or data before running this script."
  bold "It is an irreversible process. Once the setup is complete, reverting the changes may be challenging."
  confirm "Do you want to continue?"
}

if ! print_warning; then
  fail "Setup aborted. No changes have been made."
  exit 1
fi

# Run all the preferences scripts
for script in $PREF_FOLDER/*.sh; do
  # Get the name of the preference script
  full_name=$(basename $script)
  file_name=$(basename $script .sh)
  name=${file_name//-/ }  # replace '-' with ' '

  # Message describing the current script
  message="Setting $name preferences"

  # Print a task message with it
  task $message

  # Run the preference script, redirecting standard output and error
  # Change the task message to success or fail
  if output=$(bash $script 2>&1); then
    success $message
  else
    fail $message
  fi
done
