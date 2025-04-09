#!/usr/bin/env bash

###############################################################################
# This script downloads ignition from GitHub.
###############################################################################

# Check if ignition is already downloaded
IGNITION_ROOT="$HOME/.ignition"
if [ -d "$IGNITION_ROOT" ]; then
  echo "Ignition is already downloaded at $IGNITION_ROOT"
  exit 1
fi

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo "git could not be found, please install it first."
    echo "On Ubuntu, you can install it with: sudo apt install git"
    echo "On macOS, you can install it with: brew install git"
    exit 1
fi

# Download ignition
echo "Downloading ignition to $IGNITION_ROOT"
git clone --no-checkout https://github.com/marosige/ignition "$IGNITION_ROOT"
git -C "$IGNITION_ROOT" sparse-checkout init --cone
git -C "$IGNITION_ROOT" sparse-checkout set "ignition/"
git -C "$IGNITION_ROOT" checkout main
echo "Ignition downloaded to $IGNITION_ROOT"

# Run the downloaded ignition
read -p "Press Enter to start ignition, or Ctrl+C to exit..."
cd "$IGNITION_ROOT/ignition"
exec bash ignition.sh
