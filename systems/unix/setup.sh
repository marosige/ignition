#!/usr/bin/env bash

###############################################################################
# This script sets up an unix base
#
# Made by Gergely Marosi - https://github.com/marosige
###############################################################################


echo -e "$IGNITION_TASK Setting up UNIX base..."

echo -e "$IGNITION_TASK Linking dotfiles..."
if [ -z "$IGNITION_ROOT" ] || [ -z "$IGNITION_UNIX" ] || [ -z "$HOME" ]; then
  echo "One or more required environment variables are not set."
  exit 1
fi

"$IGNITION_ROOT/src/link_directory.sh" "$IGNITION_UNIX/dotfiles" "$HOME"
