#!/usr/bin/env bash

###############################################################################
# This script installs a downloaded Ignition
# Made by Gergely Marosi - https://github.com/marosige
###############################################################################

print_warning () {
  message "This script will install various applications and tools."
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
