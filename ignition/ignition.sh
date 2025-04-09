#!/usr/bin/env bash

###############################################################################
# This script is the entry point of Ignition
# It is a menu, where the user can select jobs
###############################################################################

# Set ignition environment path variables
source $HOME/.ignition/ignition/bootstrap.sh

# Check flags
# Available flags:
# -u: Only update Ignition, do not show menu
flag_update=false
while getopts "u" opt; do
  case $opt in
    u)
      flag_update=true
      ;;
    *)
      ;;
  esac
done

# Update ignition
PULL_OUTPUT=$(git -C "$IGNITION_ROOT" pull --rebase --autostash 2>&1) # Autostash to avoid conflicts when user has local changes in config files
case "$PULL_OUTPUT" in
  *"Aborting"*)
    echo -e "$IGNITION_WARN Problem with updating Ignition. Commit your local changes or stash them before you update."
    ;;
  *"Already up to date."*)
    $flag_update && echo -e "$IGNITION_DONE Ignition is up to date!"
    ;;
  *"autostash"*)
    echo -e "$IGNITION_WARN Ignition updated with autostash."
    exec "$0"
    ;;
  *)
    echo -e "$IGNITION_DONE Ignition updated!"
    exec "$0"
    ;;
esac
$flag_update && exit 0

# Warn about stashed changes
STASH_COUNT=$(git -C "$IGNITION_ROOT" stash list | wc -l | tr -d '[:space:]')
if (( STASH_COUNT > 0 )); then
  echo -e "$IGNITION_WARN You have $STASH_COUNT stash entr$( [ "$STASH_COUNT" -eq 1 ] && echo "y" || echo "ies" ) in $IGNITION_ROOT."
  echo "$IGNITION_INDENT Make sure to apply them and save the config changes by committing if needed."
fi

# Show menu
job_all="Run all jobs"
job_create_directories="Create directories"
job_link_files="Link files"
job_install_packages="Install packages"
job_configure_preferences="Configure system preferences"
job_exit="Exit"

options=(
  "$job_all"
  "$job_update_system"
  "$job_create_directories"
  "$job_link_files"
  "$job_install_packages"
  "$job_configure_preferences"
  "$job_exit"
)

case $(lib_menu "${options[@]}") in
  "$job_all")
    bash "$IGNITION_DIR/setup.sh" --all
    echo -e "$IGNITION_DONE Setting up Ignition completed!"
    ;;
  "$job_create_directories")
    bash "$IGNITION_DIR/setup.sh" --create-directories
    echo -e "$IGNITION_DONE Creating directories completed!"
    ;;
  "$job_link_files")
    bash "$IGNITION_DIR/setup.sh" --link-files
    echo -e "$IGNITION_DONE Linking files completed!"
    ;;
  "$job_install_packages")
    bash "$IGNITION_DIR/setup.sh" --install-packages
    echo -e "$IGNITION_DONE Installing packages completed!"
    ;;
  "$job_configure_preferences")
    bash "$IGNITION_DIR/setup.sh" --configure-preferences
    echo -e "$IGNITION_DONE Configuring preferences completed!"
    ;;
  "$job_exit")
    echo -e "$IGNITION_TASK Exiting..."
    ;;
esac
