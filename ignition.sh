#!/usr/bin/env bash

###############################################################################
# This script is the entry point of a downloaded Ignition
# It is a menu, where the user can select the jobs
# Made by Gergely Marosi - https://github.com/marosige
###############################################################################

source $HOME/.ignition/bootstrap.sh

# User Interface
menu () {
  question "Ignition Main Menu"

  option_apps="Install applications"
  option_preferences="Set preferences"
  option_update="Update everything"
  option_applist_manager="Application list manager"
  option_exit="Exit"

  options=(
    $option_apps
    $option_preferences
    #$option_update
    #$option_applist_manager
    $option_exit
  )

  choice=$(gum choose "${options[@]}")
  case "$choice" in
    "$option_apps" )
      "$IG_ROOT/jobs/applications.sh" && success "Installed applications successfully" || fail "Installing applications failed."
    ;;
    "$option_preferences" )
    "$IG_ROOT/jobs/preferences.sh" && success "Preferences set successfully" || fail "Preference setting failed."
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
