#!/usr/bin/env bash

echo -e "$IGNITION_TASK Checking for macOS updates..."

# Check for available updates
if ! updates=$(softwareupdate -l); then
  echo -e "$IGNITION_FAIL Failed to check for macOS updates. Please run the script with appropriate permissions."
  exit 1
fi

if [[ $updates == *"No new software available."* ]]; then
  echo -e "$IGNITION_DONE Your macOS is up to date."
else
  echo -e "$IGNITION_TASK Updates are available. Updating macOS..."
  # Install all available updates
  sudo softwareupdate -ia --verbose
  echo -e "$IGNITION_DONE macOS update completed."
fi
