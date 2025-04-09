#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# Trackpad
###############################################################################
exit=0

# Disable "natural" scrolling
#defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false || exit=1

# Tap to click for this user and for the login screen
#defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad Clicking -bool true || exit=1
#defaults -currentHost write NSGlobalDomain com.apple.mouse.tapBehavior -int 1 || exit=1
#defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1 || exit=1

# Map bottom right corner to right-click
#defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadCornerSecondaryClick -int 2 || exit=1
#defaults write com.apple.driver.AppleBluetoothMultitouch.trackpad TrackpadRightClick -bool true || exit=1
#defaults -currentHost write NSGlobalDomain com.apple.trackpad.trackpadCornerClickBehavior -int 1 || exit=1
#defaults -currentHost write NSGlobalDomain com.apple.trackpad.enableSecondaryClick -bool true || exit=1

# Tracking Speed
# 0: Slow
# 3: Fast
# 5: Max
defaults write NSGlobalDomain com.apple.trackpad.scaling -float 4.5 || exit=1

# Haptic feedback
# 0: Light
# 1: Medium
# 2: Firm
defaults write com.apple.AppleMultitouchTrackpad FirstClickThreshold -int 0 || exit=1
defaults write com.apple.AppleMultitouchTrackpad SecondClickThreshold -int 0 || exit=1

# Enable back and forward navigation with two finger horizontal scrolls. (e.g. in web browsers)
defaults write NSGlobalDomain AppleEnableSwipeNavigateWithScrolls -bool true || exit=1

exit $exit
