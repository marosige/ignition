#!/usr/bin/env bash

echo -e "$IGNITION_TASK Checking for macOS updates..."

# Check for updates
if softwareupdate -l | grep -q "No new software available."; then
  echo -e "$IGNITION_DONE Your macOS is up to date."
else
  echo -e "$IGNITION_TASK Updates found. Installing..."
  sudo softwareupdate -ia --verbose
  echo -e "$IGNITION_DONE macOS update completed."
fi
