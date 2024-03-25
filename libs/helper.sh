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
