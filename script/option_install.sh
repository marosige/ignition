#!/usr/bin/env bash

###############################################################################
# This script sets up a system from blank
###############################################################################

echo -e "$IGNITION_TASK Setting up a clean system"

echo "$IGNITION_INDENT This script is configuring system settings and preferences."
echo "$IGNITION_INDENT Please be aware that running this script will modify your system and may affect your existing configurations."
echo "$IGNITION_INDENT Ensure you have reviewed the script and understand the changes it will make before proceeding: https://github.com/marosige/ignition"
echo "$IGNITION_INDENT IMPORTANT: Backup any important configurations or data before running this script."
echo "$IGNITION_INDENT It is an irreversible process. Once the setup is complete, reverting the changes may be challenging."
ack

job() {
  TITLE=$1
  SCRIPT=$2
  JOB="$IGNITION_ACTIVE_SYSTEM/job/${SCRIPT}.sh"
  if [ -f "$JOB" ]; then
    echo -e "$IGNITION_TASK $TITLE"
    bash "$JOB"
  fi
}  

# Loop through each system directory
for system_path in "$IGNITION_SYSTEM"/*/; do
  if [ -d "$system_path" ]; then
    export IGNITION_ACTIVE_SYSTEM="$system_path"
    system_name=$(basename "$system_path")
    echo -e "$IGNITION_TASK Setting up $system_name"
    job "Updating system..." update_system
    job "Creating directories..." create_directories
    job "Linking files..." link_files
    job "Installing packages..." install_packages
    job "Configuring preferences..." configure_preferences
  fi
done