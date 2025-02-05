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

# Update ignition
cd "$IGNITION_ROOT" && git pull --quiet

#### Menu ####
option_install="Install system with Ignition"
option_exit="Exit"

# TODO when ignition is not installed yet, show only the install option and exit
# TODO hide the install option when ignition is already installed
options=(
  "$option_install"
  "$option_exit"
)

echo -e "${BOLD}Ignition Main Menu$NC"

if command -v gum &> /dev/null; then
  choice=$(gum choose "${options[@]}")
else
  PS3="Please select an option: " # Prompt for the menu
  select choice in "${options[@]}"; do
    if [ -n "$choice" ]; then
      break
    else
      echo -e "$IGNITION_FAIL Invalid option. Please try again."
    fi
  done
fi

case $choice in
  "$option_install")
    bash "$IGNITION_ROOT/src/option_install.sh"
    echo -e "$IGNITION_DONE Setting up Ignition completed!"
    ;;
  "$option_exit")
    echo -e "$IGNITION_TASK Exiting..."
    ;;
esac
