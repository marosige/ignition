#!/usr/bin/env bash

echo "Checking for macOS updates..."

# Check for available updates
if ! updates=$(softwareupdate -l); then
  echo "Failed to check for macOS updates. Please run the script with appropriate permissions."
  exit 1
fi

if [[ $updates == *"No new software available."* ]]; then
  echo "Your macOS is up to date."
else
  echo "Updates are available. Updating macOS..."
  # Install all available updates
  sudo softwareupdate -ia --verbose
  echo "macOS update completed."
fi
