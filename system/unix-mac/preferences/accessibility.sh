#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# Accessibility
###############################################################################
exit=0

# Shake mouse cursor to locate
defaults write CGDisableCursorLocationMagnification -bool true || exit=1

## Zoom

# Enable temporary zoom (Hold down ⌃⌥ to zoom when needed)
sudo defaults write com.apple.universalaccess closeViewPressOnReleaseOff -bool false || exit=1

# Zoom using scroll gesture with the Ctrl (^) modifier key
sudo defaults write com.apple.universalaccess closeViewScrollWheelToggle -bool true || exit=1
sudo defaults write com.apple.universalaccess HIDScrollZoomModifierMask -int 262144 || exit=1

# Smooth Zoomed Images
sudo defaults write com.apple.universalaccess closeViewSmoothImages -bool false || exit=1

# Follow the keyboard focus while zoomed
sudo defaults write com.apple.universalaccess closeViewZoomFollowsFocus -bool true || exit=1

# Zoom Style
# Fullscreen: 0
# Picture-in-picture: 1
sudo defaults write com.apple.universalaccess closeViewZoomMode -int 0 || exit=1

exit $exit
