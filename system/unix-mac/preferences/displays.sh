#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# Displays
###############################################################################
exit=0

# Automatically adjust brightness
defaults write com.apple.BezelServices dAuto -bool true || exit=1
sudo defaults write /Library/Preferences/com.apple.iokit.AmbientLightSensor "Automatic Display Enabled" -bool true || exit=1

# Subpixel font rendering on non-Apple LCDs
# 0 : Disabled
# 1 : Minimal
# 2 : Medium
# 3 : Smoother
# 4 : Strong
defaults write NSGlobalDomain AppleFontSmoothing -int 2 || exit=1

# Enable HiDPI display modes (requires restart)
sudo defaults write /Library/Preferences/com.apple.windowserver DisplayResolutionEnabled -bool true || exit=1

# Show mirroring options in the menu bar when available
defaults write com.apple.airplay showInMenuBarIfPresent -bool true || exit=1

exit $exit
