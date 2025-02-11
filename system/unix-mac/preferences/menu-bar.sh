#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Menu bar
###############################################################################
exit=0

# Show battery percentage
defaults write com.apple.controlcenter BatteryShowPercentage -bool true || exit=1

# Show bluetooth icon
defaults write com.apple.controlcenter Bluetooth -int 18 || exit=1

# Show volume icon
defaults write com.apple.controlcenter Sound -int 18 || exit=1

# Show text input menu
defaults write com.apple.TextInputMenu visible -bool true || exit=1

# Show mirroring options in the menu bar when available
defaults write com.apple.airplay showInMenuBarIfPresent -bool true || exit=1

exit $exit
