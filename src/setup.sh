#!/usr/bin/env bash

###############################################################################
# This script sets up a system from blank
#
# Made by Gergely Marosi - https://github.com/marosige
###############################################################################

echo -e "$IGNITION_TASK Setting up a clean system"

echo "$IGNITION_INDENT This script is configuring system settings and preferences."
echo "$IGNITION_INDENT Please be aware that running this script will modify your system and may affect your existing configurations."
echo "$IGNITION_INDENT Ensure you have reviewed the script and understand the changes it will make before proceeding: https://github.com/marosige/ignition"
echo "$IGNITION_INDENT IMPORTANT: Backup any important configurations or data before running this script."
echo "$IGNITION_INDENT It is an irreversible process. Once the setup is complete, reverting the changes may be challenging."
read -r -p "Press [ENTER] to continue, or Ctrl-c to cancel."

setup() {
  TITLE=$1
  SCRIPT=$2
  echo -e "$IGNITION_TASK $TITLE"
  if [ -f "$IGNITION_UNIX/src/${SCRIPT}.sh" ]; then
    bash "$IGNITION_UNIX/src/${SCRIPT}.sh"
  fi
  if [ -f "$IGNITION_OS/src/${SCRIPT}.sh" ]; then
    bash "$IGNITION_OS/src/${SCRIPT}.sh"
  fi
}

setup "Updating system..." update_system
setup "Creating directories..." create_directories
setup "Linking files..." link_files
setup "Installing packages..." install_packages
setup "Configuring preferences..." configure_preferences
