#!/usr/bin/env bash

###############################################################################
# This script is the bootstrap script for ignition
###############################################################################

# Set ignition environment path variables
export IGNITION_ROOT="$HOME/.ignition"
export IGNITION_LIB="$IGNITION_ROOT/lib"
export IGNITION_SCRIPT="$IGNITION_ROOT/script"
export IGNITION_SYSTEM="$IGNITION_ROOT/system"
export IGNITION_ACTIVE_SYSTEM="Set this to the active system directory"

# Set log messages
BOLD='\033[1m'
BRIGHT_BLUE='\033[0;94m'
BRIGHT_GREEN='\033[0;92m'
YELLOW='\033[0;33m'
BRIGHT_RED='\033[0;91m'
NC='\033[0m' # No Color (resets to default)

export IGNITION_TITLE="${BOLD}[#]${NC}"
export IGNITION_TASK="${BRIGHT_BLUE}[>]${NC}"
export IGNITION_DONE="${BRIGHT_GREEN}[✔]${NC}"
export IGNITION_ADD="${BRIGHT_GREEN}[+]${NC}"
export IGNITION_WARN="${YELLOW}[!]${NC}"
export IGNITION_FAIL="${BRIGHT_RED}[✖]${NC}"
export IGNITION_INDENT="   "

# Add the IGNITION_LIB directory to the PATH
if [ -d "$IGNITION_LIB" ]; then
    export PATH="$IGNITION_LIB:$PATH"
fi

# small functions for ignition, not big enough to be in a separate lib file
ack() {
    local action="${1:-continue}"
    echo -e "$IGNITION_WARN Press [ENTER] to $action, or Ctrl-c to cancel."
    read -r
}
export -f ack

is_command_exists() {
    command -v "$1" >/dev/null 2>&1
}
export -f is_command_exists

mkdir_withlog() {
  if [ -d "$1" ]; then
    echo -e "$IGNITION_DONE Directory already exists: $1"
  else
    mkdir -p "$1"
    echo -e "$IGNITION_ADD Created directory: $1"
  fi
}
export -f mkdir_withlog