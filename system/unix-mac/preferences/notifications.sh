#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# Notifications
###############################################################################
exit=0

# Disable Notification Center and remove the menu bar icon
#launchctl unload -w /System/Library/LaunchAgents/com.apple.notificationcenterui.plist 2> /dev/null

# Notification banner on screen time
# Default 5 seconds
defaults write com.apple.notificationcenterui bannerTime 2 || exit=1

exit $exit
