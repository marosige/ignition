#!/usr/bin/env bash

###############################################################################
# This script installs every Ignition jobs in order to set up a system
#
# Made by Gergely Marosi - https://github.com/marosige
###############################################################################

INSTALL_FOLDER="$IG_OS/installers"

# Check if the folder exists and is not empty
if [[ ! -d "$INSTALL_FOLDER" || -z "$(ls -A "$INSTALL_FOLDER" 2>/dev/null)" ]]; then
    warn "Folder $INSTALL_FOLDER does not exist or is empty. Doing nothing."
    exit 1
fi

print_warning () {
  message "This script will install my preffered enviroment and applications"
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

# Ask for the administrator password upfront
sudo -v

# Keep-alive: update existing `sudo` time stamp until script has finished
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

# Export the OS required IG_INSTALLER_ORDER array
source $INSTALL_FOLDER/_install_order.sh

# Sources all the preference files
function source_installers {
  declare -a files=("${!1}")
  for file in "${files[@]}"; do
    file="${2}${file}.sh"
    [ -r "$file" ] && [ -f "$file" ] && source $file $log_file
  done;
}

source_installers IG_INSTALLER_ORDER[@] "$INSTALL_FOLDER"
