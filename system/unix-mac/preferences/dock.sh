#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# Dock
###############################################################################
exit=0

## Dock preferences

# Set dock icon standard size to 32px
defaults write com.apple.dock tilesize -int 32 || exit=1

# Set dock icon magnified size to 48px
defaults write com.apple.dock largesize -int 48 || exit=1

# Enable dock magnification
defaults write com.apple.dock magnification -bool true || exit=1

# Lock the Dock size (disable the arrows to change it easily)
defaults write com.apple.dock size-immutable -bool true || exit=1

# Set the minimize animation effect to scale
defaults write com.apple.dock mineffect -string scale || exit=1

# Set do not display recent apps in the dock
defaults write com.apple.dock show-recents -bool false || exit=1

# Scroll up on a Dock icon to show all Space's opened windows for an app.
defaults write com.apple.dock scroll-to-open -bool true || exit=1

# Set dock position to the bottom
defaults write com.apple.dock orientation -string bottom || exit=1

# Set display pinned apps in the dock (default)
defaults write com.apple.dock static-only -bool false || exit=1

# Set disable dock auto hide (default)
defaults write com.apple.dock autohide -bool false || exit=1

# Restart dock to apply changes
killall Dock

exit $exit
