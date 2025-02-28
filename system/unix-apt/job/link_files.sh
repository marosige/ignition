#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Link files from the dotfiles directory to the home directory
###############################################################################

# Link dotfiles to the home directory
lib_link_directories "$IGNITION_ACTIVE_SYSTEM/dotfiles" "$HOME"
