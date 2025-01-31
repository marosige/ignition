#!/usr/bin/env bash

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

## Dock items

# Clear the dock
dockutil --remove all --no-restart || exit=1

# Sleep 1 second, because quickly calling dockutil can cause issues
sleep 1

# Add persistent-apps
dockutil --add '' --type small-spacer --section apps --no-restart || exit=1
dockutil --add '/Applications/Google Chrome.app' --no-restart || exit=1
dockutil --add '/Applications/ChatGPT.app' --no-restart || exit=1
dockutil --add "$HOME/Applications/YT Music.app" --no-restart || exit=1
dockutil --add '' --type small-spacer --section apps --no-restart || exit=1
dockutil --add '/Applications/Messenger.app' --no-restart || exit=1
dockutil --add '/System/Applications/Messages.app' --no-restart || exit=1
dockutil --add '/Applications/WhatsApp.app' --no-restart || exit=1
dockutil --add '' --type small-spacer --section apps --no-restart || exit=1
dockutil --add '/System/Applications/Calendar.app' --no-restart || exit=1
dockutil --add '/System/Applications/Reminders.app' --no-restart || exit=1
dockutil --add '/System/Applications/Notes.app' --no-restart || exit=1
dockutil --add '/Applications/1Password.app' --no-restart || exit=1
dockutil --add '/System/Applications/Utilities/Screenshot.app' --no-restart || exit=1
dockutil --add '' --type small-spacer --section apps --no-restart || exit=1
dockutil --add '/Applications/Slack.app' --no-restart || exit=1
dockutil --add '' --type small-spacer --section apps --no-restart || exit=1
dockutil --add '/System/Applications/Utilities/Terminal.app' --no-restart || exit=1
dockutil --add '/Applications/Fork.app' --no-restart || exit=1
dockutil --add '/Applications/Visual Studio Code.app' --no-restart || exit=1
dockutil --add '/Applications/Android Studio.app' --no-restart || exit=1
dockutil --add '' --type small-spacer --section apps --no-restart || exit=1

# Add persistent-others
dockutil --add "$HOME/Downloads" --view fan --display stack --sort dateadded --no-restart || exit=1

# Sleep 1 second, because quickly calling dockutil can cause issues
sleep 1

# Restart dock to apply changes
killall Dock

exit $exit
