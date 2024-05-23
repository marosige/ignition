#!/usr/bin/env bash

isIgnitionInstalled=true
# If IGNITION is not set, .env is not sourced)
if ! [ -d "$IGNITION" ]; then
  source $HOME/.ignition/global/dotfiles/env/env.sh
  isIgnitionInstalled=false
fi

source $IGNITION_LIB_PRINT
source $IGNITION_LIB_HELPER

cd $IGNITION

# Read the script parameters
auto_accept=false
auto_update=false

while getopts ":yuh" opt; do
  case $opt in
    y)
      auto_accept=true
      ;;
    u)
      auto_update=true
      ;;
    h)
      title "Usage: $0 [-y] [-i]"
      message "Options:"
      message "  -y: Auto-accept without prompting."
      message "  -u: Run update without showing the menu."
      exit 0
      ;;
    \?)
      fail "Invalid option: -$OPTARG. Use -h for help." >&2
      exit 1
      ;;
  esac
done

print_warning () {
  message "This script is designed to set up your environment by performing the following actions:"
  message " 1. Installing various applications and tools."
  message " 2. Configuring system settings and preferences."
  info "Please be aware that running this script will modify your system and may affect your existing configurations."
  message "Ensure you have reviewed the script and understand the changes it will make before proceeding: https://github.com/marosige/ignition"
  warn "IMPORTANT: Backup any important configurations or data before running this script."
  bold "It is an irreversible process. Once the setup is complete, reverting the changes may be challenging."
  confirm "Do you want to continue?"
}

exit_if_not_accepted () {
  if [ "$auto_accept" = false ]; then
    if ! print_warning ; then
      fail "Setup aborted. No changes have been made."
      exit 1
    fi
  fi
}

ignite () {
  exit_if_not_accepted
  bash $IGNITION_SCRIPTS_INSTALL
  bash $IGNITION_SCRIPTS_PREFERENCES
  success "Task finished! Reboot your computer to finalize the setup!"
}

menu () {
  question "Ignition Main Menu"

  option_preferences="Set preferences"
  option_update="Update"
  option_homebrew="Homebrew cleaner"
  option_exit="Exit"

  options=($option_preferences $option_update)
  if runningOnMacOs; then
    options=("${options[@]}" $option_homebrew )
  fi
  options=("${options[@]}" $option_exit )

  choice=$(gum choose "${options[@]}")
  case "$choice" in
    "$option_preferences" )
      bash $IGNITION_SCRIPTS_PREFERENCES
    ;;
    "$option_update" )
      bash $IGNITION_SCRIPTS_UPDATE
    ;;
    "$option_homebrew" )

    ;;
    "$option_exit" )
    success "Exiting"
    exit 0
    ;;
  esac
  menu
}

if ! isIgnitionInstalled ; then
  ignite
else
  if [ "$auto_update" = true ]; then
    bash $IGNITION_SCRIPTS_UPDATE
    exit 0  # When auto updating, do not show the menu
  fi
  menu
fi
