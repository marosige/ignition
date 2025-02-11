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
fi

# Show menu
option_install="Install system with Ignition"
option_configure_preferences="Configure system preferences"
option_exit="Exit"

# TODO when ignition is not installed yet, show only the install option and exit
# TODO hide the install option when ignition is already installed
options=(
  "$option_install"
  "$option_configure_preferences"
  "$option_exit"
)

echo -e "$IGNITION_TITLE Ignition Main Menu"
choice=$(lib_menu "${options[@]}")

case "$choice" in
  "$option_install")
    bash "$IGNITION_ROOT/script/option_install.sh"
    echo -e "$IGNITION_DONE Setting up Ignition completed!"
    ;;
  "$option_configure_preferences")
    bash "$IGNITION_ROOT/script/option_configure_preferences.sh"
    echo -e "$IGNITION_DONE Configuring Ignition preferences completed!"
    ;;
  "$option_exit")
    echo -e "$IGNITION_TASK Exiting..."
    ;;
esac
