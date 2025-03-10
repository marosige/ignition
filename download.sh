#!/usr/bin/env bash

###############################################################################
# This script downloads ignition for your system
# Supported systems are macOS and Ubuntu
# Dependencies: git, homebrew (macOS)
###############################################################################

# Bootstrap
export IGNITION_ROOT="$HOME/.ignition"
export IGNITION_LIB="$IGNITION_ROOT/lib"
export IGNITION_SCRIPT="$IGNITION_ROOT/script"
export IGNITION_SYSTEM="$IGNITION_ROOT/system"
export IGNITION_ACTIVE_SYSTEM="Set this to the active system directory"
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
ack() {
    local action="${1:-continue}"
    echo -e "$IGNITION_WARN Press [ENTER] to $action, or Ctrl-c to cancel."
    read -r
}
is_command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if ignition folder already exists
if [ -d "$IGNITION_ROOT" ]; then
  echo -e "$IGNITION_FAIL Ignition is already downloaded at $IGNITION_ROOT"
  ack "run ignition"
  cd "$IGNITION_ROOT" || exit 1
  exec bash ignition.sh
  exit 0
fi

# Define the systems to download
SYSTEMS=("unix") # Base system

# Set the os, and check dependencies
case "$(uname)" in
  Darwin)
    SYSTEMS+=("unix-mac")
    if ! is_command_exists brew ; then (/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || echo -e "$IGNITION_FAIL Failed to install Homebrew on macOS" && exit 1); fi
    if ! is_command_exists git ; then (brew install git || echo -e "$IGNITION_FAIL Failed to install Git on macOS" && exit 1); fi
    ;;
  Linux)
    if is_command_exists apt-get; then
      SYSTEMS+=("unix-apt")
      sudo apt-get update
      if ! is_command_exists git ; then (sudo apt-get install -y git || (echo -e "$IGNITION_FAIL Failed to install Git on Linux apt" && exit 1)) fi
    else
      echo -e "$IGNITION_FAIL Unsupported Linux distribution"
      exit 1
    fi
    ;;
  *)
    echo -e "$IGNITION_FAIL Unsupported operating system"
    echo -e "$IGNITION_INDENT Ignition is available on macOS and Ubuntu"
    exit 1
    ;;
esac

echo -e "$IGNITION_TASK Downloading ignition for ${SYSTEMS[*]} into $IGNITION_ROOT"
SYSTEMS=("${SYSTEMS[@]/#/system/}") # Add the system directory prefix
git clone --no-checkout https://github.com/marosige/ignition "$IGNITION_ROOT"
git -C "$IGNITION_ROOT" sparse-checkout init --cone
git -C "$IGNITION_ROOT" sparse-checkout set "script/" "lib/" "${SYSTEMS[@]}"
git -C "$IGNITION_ROOT" checkout main

echo -e "$IGNITION_DONE Ignition downloaded successfully"

ack "run ignition"

cd "$IGNITION_ROOT" || exit
exec bash ignition.sh
