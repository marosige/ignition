#!/usr/bin/env bash

###############################################################################
# Mission Control
###############################################################################
exit=0

# Automatically rearrange Spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false || exit=1

# When switching to an application, switch to a Space with open windows for the application
defaults write NSGlobalDomain AppleSpacesSwitchOnActivate -bool true || exit=1

# Displays have seperate Spaces
defaults write com.apple.spaces spans-displays -bool false || exit=1

exit $exit
