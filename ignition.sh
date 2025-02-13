#!/usr/bin/env bash

###############################################################################
# This script is the entry point of Ignition
# It is a menu, where the user can select jobs
###############################################################################

source ~/.ignition/bootstrap.sh

# Update ignition
PULL_OUTPUT=$(git -C "$IGNITION_ROOT" pull 2>&1)
if ! echo "$PULL_OUTPUT" | grep -q "Already up to date."; then
    echo -e "$IGNITION_DONE Ignition updated!"
    bash "$0"
    exit
fi

echo -e "$IGNITION_WARN Read carefully!"
echo "$IGNITION_INDENT This script is configuring system settings and preferences."
echo "$IGNITION_INDENT Please be aware that running this script will modify your system and may affect your existing configurations."
echo "$IGNITION_INDENT Ensure you have reviewed the script and understand the changes it will make before proceeding: https://github.com/marosige/ignition"
echo "$IGNITION_INDENT IMPORTANT: Backup any important configurations or data before running this script."
echo "$IGNITION_INDENT It is an irreversible process. Once the setup is complete, reverting the changes may be challenging."

# Show menu
job_install="Install system with Ignition (all jobs)"
job_update_system="Update system"
job_create_directories="Create directories"
job_link_files="Link files"
job_install_packages="Install packages"
job_configure_preferences="Configure system preferences"
job_exit="Exit"

# If ignition is not installed yet, only show the install option
if [ -L "$HOME/bin/ignition" ]; then
  options=(
    "$job_install"
    "$job_update_system"
    "$job_create_directories"
    "$job_link_files"
    "$job_install_packages"
    "$job_configure_preferences"
    "$job_exit"
  )
else
  ack
  options=(
    "$job_install"
    "$job_exit"
  )
fi

choice=$(lib_menu "${options[@]}")

case "$choice" in
  "$job_install")
    bash "$IGNITION_ROOT/script/run_job.sh" --all
    echo -e "$IGNITION_DONE Setting up Ignition completed!"
    ;;
  "$job_update_system")
    bash "$IGNITION_ROOT/script/run_job.sh" --update-system
    echo -e "$IGNITION_DONE Updating system completed!"
    ;;
  "$job_create_directories")
    bash "$IGNITION_ROOT/script/run_job.sh" --create-directories
    echo -e "$IGNITION_DONE Creating directories completed!"
    ;;
  "$job_link_files")
    bash "$IGNITION_ROOT/script/run_job.sh" --link-files
    echo -e "$IGNITION_DONE Linking files completed!"
    ;;
  "$job_install_packages")
    bash "$IGNITION_ROOT/script/run_job.sh" --install-packages
    echo -e "$IGNITION_DONE Installing packages completed!"
    ;;
  "$job_configure_preferences")
    bash "$IGNITION_ROOT/script/run_job.sh" --configure-preferences
    echo -e "$IGNITION_DONE Configuring preferences completed!"
    ;;
  "$job_exit")
    echo -e "$IGNITION_TASK Exiting..."
    ;;
esac
