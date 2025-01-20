#!/usr/bin/env bash

###############################################################################
# This script is the entry point of Ignition
# It is a menu, where the user can select jobs
#
# Made by Gergely Marosi - https://github.com/marosige
###############################################################################

#### Bootstrap ####

## Set ignition path variables

# Export location of the ignition script
IGNITION_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export IGNITION_DIR

# Export location of the root of Ignition project
IGNITION_ROOT="$(dirname "$IGNITION_DIR")"
export IGNITION_ROOT

# Export location of the global directory
export IGNITION_GLOBAL="$IGNITION_ROOT/_global"

# Export location of the OS specific directory
MACOS_DIR="$IGNITION_ROOT/_macos"
UBUNTU_DIR="$IGNITION_ROOT/_ubuntu"
if [ -d "$MACOS_DIR" ]; then
  export IGNITION_OS=$MACOS_DIR
elif [ -d "$UBUNTU_DIR" ]; then
  export IGNITION_OS=$UBUNTU_DIR
else
  echo "Error: Can't identify OS." >&2
  exit 1
fi

## Source the print library
source "$IGNITION_DIR/print/print.sh"

## Source the OS specific env (It is important for first runs wintohut an installed ignition)
source "$IGNITION_OS/files/env/env.sh"

#### Menu ####

menu () {
  question "Ignition Main Menu"

  option_install="Run installers"
  option_preferences="Set preferences"
  option_update="Update everything"
  option_applist_manager="Application list manager"
  option_exit="Exit"

  options=(
    $option_install
    $option_preferences
    #$option_update
    #$option_applist_manager
    $option_exit
  )

  choice=$(gum choose "${options[@]}")
  case "$choice" in
    "$option_install" )
      "$IGNITION_DIR/jobs/install.sh" && success "Installed Ignition successfully" || fail "Installing Ignition failed."
    ;;
    "$option_preferences" )
    "$IGNITION_DIR/jobs/preferences.sh" && success "Preferences set successfully" || fail "Preference setting failed."
    ;;
    "$option_update" )

    ;;
    "$option_applist_manager" )

    ;;
    "$option_exit" )
    success "Exiting..."
    exit 0
    ;;
  esac
  menu
}

menu
