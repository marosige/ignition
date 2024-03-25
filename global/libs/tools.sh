#!/usr/bin/env bash

###############################################################################
# Useful helper functions
# Made by Gergely Marosi - https://github.com/marosige
###############################################################################

# Function: is_command_exists
# Description: Checks if a command exists in the system.
# Parameters:
#   $1: The name of the command to check for existence.
# Return:
#   Returns 0 (success) if the command exists, non-zero otherwise.
#   Redirects any output or errors to /dev/null to suppress them.
# Usage:
#   is_command_exists <command_name>
#   Example: is_command_exists "ls"
#       This will return 0 if the "ls" command exists, otherwise, it will return non-zero.
function is_command_exists() {
    type "$1" &> /dev/null
}
