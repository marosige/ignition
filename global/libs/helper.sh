#!/usr/bin/env bash

###############################################################################
# Helper functions for ignition scripts
# Made by Gergely Marosi - https://github.com/marosige#
###############################################################################

# Function to check if a command exists
# Parameters:
#   $1: Command to check for existence
# Returns:
#   0 if the command exists, 1 otherwise
is_command_exists() {
  command -v "$1" &> /dev/null
}

# Function to check if the system is running macOS
# Returns:
#   0 if the system is macOS, 1 otherwise
running_on_macos() {
  [ "$(uname)" = "Darwin" ]
}

# Function to check if the system is running Ubuntu (by checking if 'apt-get' command exists)
# Returns:
#   0 if the system is Ubuntu, 1 otherwise
running_on_ubuntu() {
  is_command_exists apt-get
}

# Function to check if the folder specified by $IGNITION_MAC exists
# Returns:
#   0 if the folder exists, 1 otherwise
has_macos_folder() {
  [ -d "$IGNITION_MAC" ]
}

# Function to check if the folder specified by $IGNITION_LAB exists
# Returns:
#   0 if the folder exists, 1 otherwise
has_ubuntu_folder() {
  [ -d "$IGNITION_LAB" ]
}

# Function to check if both MacOsFolder and UbuntuFolder exist
# Returns:
#   true if both folders exist, false otherwise
has_system_folders() {
  has_macos_folder && has_ubuntu_folder
}
