#!/usr/bin/env bash

###############################################################################
# This script downloads ignition for your system
# Supported systems are macOS and Ubuntu
# Dependencies: git, homebrew (macOS)
#
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

# Set the download destination
# Default to $HOME/.ignition, but allow overriding with the first parameter
if [[ -n "$1" ]]; then
    export IGNITION_ROOT="$1"  # Use the first parameter as the destination
else
    export IGNITION_ROOT="$HOME/.ignition"  # Default destination
fi

# Check if the destination folder already exists
if [ -d "$IGNITION_ROOT" ]; then
  echo "Error: Ignition is already downloaded at $IGNITION_ROOT"
  exit 1
fi

# Set the os, and check dependencies
if running_on_macos; then
  OS="mac"
  if ! is_command_exists brew ; then (/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)" || echo "Failed to install Homebrew on macOS" && exit 1); fi
  if ! is_command_exists git ; then (brew install git || echo "Failed to install Git on macOS" && exit 1); fi
elif running_on_ubuntu; then
  OS="ubuntu"
  sudo apt-get update
  if ! is_command_exists git ; then (sudo apt-get install -y git || (echo "Failed to install Git on Ubuntu" && exit 1)); fi
else
  echo "Unsupported operating system"
  echo "Ignition is available on macOS and Ubuntu"
  exit 1
fi

echo "Downloading ignition for $OS into $IGNITION_ROOT"
git clone --no-checkout https://github.com/marosige/ignition "$IGNITION_ROOT"
git -C "$IGNITION_ROOT" sparse-checkout init --cone
git -C "$IGNITION_ROOT" sparse-checkout set src/ systems/unix/ systems/$OS/
git -C "$IGNITION_ROOT" checkout main

echo "Ignition downloaded successfully"
echo "Press [ENTER] to run it, or Ctrl-c to cancel."
read
cd "$IGNITION_ROOT" || exit
exec bash ignition.sh
