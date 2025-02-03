#!/usr/bin/env bash

###############################################################################
# Link files for macOS
###############################################################################

# Link keylayout to /Library/Keyboard Layouts, since it's not inside the HOME directory, so it's not linked by link_directory.sh
ln -s "$IGNITION_OS/dotfiles/Library/Keyboard Layouts/en_hu.keylayout" "/Library/Keyboard Layouts/en_hu.keylayout"
