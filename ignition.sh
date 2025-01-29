#!/usr/bin/env bash

###############################################################################
# This script is the entry point of Ignition
# It is a menu, where the user can select jobs
#
# Made by Gergely Marosi - https://github.com/marosige
###############################################################################

#### Bootstrap ####

# Set ignition environment path variables
IGNITION_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export IGNITION_ROOT

export IGNITION_UNIX="$IGNITION_ROOT/systems/unix"

MACOS_DIR="$IGNITION_ROOT/systems/mac"
UBUNTU_DIR="$IGNITION_ROOT/systems/ubuntu"
if [ -d "$MACOS_DIR" ]; then
  export IGNITION_OS=$MACOS_DIR
elif [ -d "$UBUNTU_DIR" ]; then
  export IGNITION_OS=$UBUNTU_DIR
else
  echo "Error: Can't identify OS." >&2
  exit 1
fi

# Set log messages
BRIGHT_BLUE='\e[0;94m'
BRIGHT_GREEN='\e[0;92m'
YELLOW='\e[0;33m'
BRIGHT_RED='\e[0;91m'
BOLD='\e[1m'
NC='\033[0m' # No Color (resets to default)

export IGNITION_TASK="${BRIGHT_BLUE}[>]${NC}"
export IGNITION_DONE="${BRIGHT_GREEN}[✔]${NC}"
export IGNITION_WARN="${YELLOW}[!]${NC}"
export IGNITION_FAIL="${BRIGHT_RED}[✖]${NC}"
export IGNITION_INDENT="   "

#### Menu ####
option_setup="Setup clean system"
option_exit="Exit"

options=(
  "$option_setup"
  "$option_exit"
)

echo -e "${BOLD}Ignition Main Menu$NC"
PS3="Please select an option: " # Prompt for the menu
select opt in "${options[@]}"; do
  case $opt in
    "$option_setup")
      bash "$IGNITION_ROOT/src/setup.sh"
      echo -e "$IGNITION_DONE Setting up Ignition completed!"
      break
      ;;
    "$option_exit")
      echo -e "$IGNITION_TASK Exiting..."
      break
      ;;
    *)
      echo -e "$IGNITION_FAIL Invalid option. Please try again."
      ;;
  esac
done
