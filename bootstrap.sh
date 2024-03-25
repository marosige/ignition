#!/usr/bin/env bash

###############################################################################
# Downloads ignition for your system
# Made by Gergely Marosi - https://github.com/marosige
#
# This script will:
# * install Homebrew (the Missing Package Manager for macOS or Linux)
# * install git (distributed version control system)
# * install gum (a tool for glamorous shell scripts)
# * sparse checkout the os and function relevant part of ignition
# * run ignition
#
###############################################################################

source <(curl -s https://raw.githubusercontent.com/marosige/ignition/main/global/libs/print.sh)
source <(curl -s https://raw.githubusercontent.com/marosige/ignition/main/global/libs/tools.sh)
source <(curl -s https://raw.githubusercontent.com/marosige/ignition/main/global/dotfiles/env/env.sh)

if [ "$(uname -s)" == "Darwin" ]; then
  os="macOS"
  function="daily driver"
elif [ is_command_exists apt-get ]; then
  os="Ubuntu"
  function="homelab"
else
  fail "Unsupported operating system"
  exit 1
fi

# Check if ignition is already downloaded
if [ -d "$IGNITION_ROOT/.git" ]; then
  cd $IGNITION_ROOT
  task "Updating ignition..."
  git pull && success "Ignition updated" || fail "Failed to update ignition"
  bash ignition.sh
else
  # Ignigion is not downloaded
  title "Welcome to Ignition!"
  message "Ignition is designed to set up your $os environment as a $function by performing the following actions:"
  message "1. Downloading Ignition into $IGNITION_ROOT"
  message "2. Installing various applications and tools."
  message "3. Configuring system settings and preferences."
  info "Please be aware that running this script will modify your system and may affect your existing configurations."
  message "Ensure you have reviewed the script and understand the changes it will make before proceeding: https://github.com/marosige/ignition"
  warn "IMPORTANT: Backup any important configurations or data before running this script."
  bold "It is an irreversible process. Once the setup is complete, reverting the changes may be challenging."
  if confirm "Do you want to continue?" ; then
    task "Installing dependencies (if missing)"
    case $os in
      "macOS")
        if ! is_command_exists brew ; then /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)" ; fi
        if ! is_command_exists git ; then brew install git ; fi
        if ! is_command_exists gum ; then brew install gum ; fi
        ;;
      "Ubuntu")
        # apt is installed by default, lets update it
        sudo apt update
        # Install git
        if ! is_command_exists git ; then sudo apt install git ; fi
        # Install gum
        if ! is_command_exists gum ; then
          sudo mkdir -p /etc/apt/keyrings
          curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
          echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
          sudo apt install gum
        fi
        ;;
    esac

    task "Sparse cloning the $os $function part of the repository."
    git clone --no-checkout https://github.com/marosige/ignition $IGNITION_ROOT  >> $log_file 2>&1
    git -C $IGNITION_ROOT sparse-checkout init --cone  >> $log_file 2>&1
    git -C $IGNITION_ROOT sparse-checkout set global/ $os/  >> $log_file 2>&1
    git -C $IGNITION_ROOT checkout main  >> $log_file 2>&1

    t "Starting the setup process."
    cd $IGNITION_MAC
    bash ignition.sh -y
  else
    fail "Setup aborted. No changes have been made."
  fi
fi
