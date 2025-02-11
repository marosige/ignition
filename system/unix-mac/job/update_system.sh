#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

echo -e "$IGNITION_TASK Checking for macOS updates..."

# Capture update output
updates=$(softwareupdate -l 2>&1)

# Check for updates
if echo "$updates" | grep -q "No new software available."; then
  echo -e "$IGNITION_DONE Your macOS is up to date."
else
  echo -e "$IGNITION_TASK Updates found. Installing..."
  sudo softwareupdate -ia --verbose
  echo -e "$IGNITION_DONE macOS update completed."
fi
