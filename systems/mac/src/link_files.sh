#!/usr/bin/env bash

###############################################################################
# Link Files
###############################################################################

# Define the source and target directories
SOURCE_DIR="$IGNITION_OS/dotfiles"
TARGET_DIR="$HOME"

# Call the linkdirectory script
bash "$IGNITION_ROOT/src/linkdirectory.sh" "$SOURCE_DIR" "$TARGET_DIR"