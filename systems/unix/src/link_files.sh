#!/usr/bin/env bash

###############################################################################
# Link files from the dotfiles directory to the home directory
###############################################################################

# Call the linkdirectory script on the dotfiles directories
bash "$IGNITION_ROOT/src/link_directory.sh" "$IGNITION_UNIX/dotfiles" "$HOME"
bash "$IGNITION_ROOT/src/link_directory.sh" "$IGNITION_OS/dotfiles" "$HOME"