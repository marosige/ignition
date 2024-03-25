#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Screenshot
###############################################################################
exit=0

# Disable thumbnail after taking a screenshot
defaults write com.apple.screencapture show-thumbnail -bool false || exit=1

# Save screenshots in PNG format (other options: BMP, GIF, JPG, PDF, TIFF)
defaults write com.apple.screencapture type -string "png" || exit=1

exit $exit
