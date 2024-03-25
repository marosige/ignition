#!/usr/bin/env bash

###############################################################################
# This script downloads ignition for your system
# Supported systems are macOS and Ubuntu
# Made by Gergely Marosi - https://github.com/marosige
###############################################################################

is_command_exists() {
  command -v "$1" >/dev/null 2>&1
}

running_on_macos() {
  [ "$(uname)" = "Darwin" ]
}

# It can be any other OS with apt-get like Debian, but let's assume it's Ubuntu
running_on_ubuntu() {
  is_command_exists apt-get
}

# Download destination is $HOME/.ignition
IGNITION_ROOT="$HOME/.ignition"

# Check if the destination folder already exists
if [ -d "$IGNITION_ROOT" ]; then
  echo "Ignition is already downloaded."
  ## TODO Implement update here
  exit 1
fi

# Set the os, and check dependencies
if running_on_macos; then
  OS="macos"
  if ! is_command_exists brew ; then /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)" || echo "Failed to install Homebrew on macOS" && exit 1; fi
  if ! is_command_exists git ; then brew install git || echo "Failed to install Git on macOS" && exit 1; fi
  if ! is_command_exists gum ; then brew install gum || echo "Failed to install Gum on macOS" && exit 1; fi
elif running_on_ubuntu; then
  OS="ubuntu"
  sudo apt-get update
  if ! is_command_exists git ; then sudo apt-get install -y git || echo "Failed to install Git on Ubuntu" && exit 1; fi
  if ! is_command_exists gum ; then
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://repo.charm.sh/apt/gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/charm.gpg
    echo "deb [signed-by=/etc/apt/keyrings/charm.gpg] https://repo.charm.sh/apt/ * *" | sudo tee /etc/apt/sources.list.d/charm.list
    sudo apt install || echo "Failed to install Gum on Ubuntu" && exit 1
  fi
else
  echo "Unsupported operating system"
  echo "Ignition is available on macOS and Ubuntu"
  exit 1
fi

echo "Downloading ignition for $OS into $IGNITION_ROOT"
git clone --no-checkout https://github.com/marosige/ignition "$IGNITION_ROOT"
git -C "$IGNITION_ROOT" sparse-checkout init --cone
git -C "$IGNITION_ROOT" sparse-checkout set _global/ "_$OS/"
git -C "$IGNITION_ROOT" checkout main

cd $IGNITION_ROOT
echo "Ignition downloaded succesfully"
read -r -p $'Do you want to run it? ' response
case "$response" in
    [yY][eE][sS]|[yY])
        bash ignition.sh
        ;;
    *)
        false
        ;;
esac
