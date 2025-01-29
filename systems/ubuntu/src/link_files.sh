#!/usr/bin/env bash

echo -e "$IGNITION_TASK Linking dotfiles..."
"$IGNITION_ROOT/src/link_directory.sh" $IGNITION_OS/dotfiles  $HOME
