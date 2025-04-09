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

## Dock items

# Clear the dock
dockutil --remove all --no-restart || exit=1

# Sleep 1 second, because quickly calling dockutil can cause issues
sleep 1

# Add things to the dock
addApp() {
    local app_path="$1"
    local app_name=$(basename "$app_path" .app)
    echo "adding [$app_name]"
    dockutil --add "$app_path" --no-restart &> /dev/null || exit=1
}

addSpace() {
    echo "adding [ ]"
    dockutil --add '' --type small-spacer --section apps --no-restart &> /dev/null || exit=1
}

addFolder() {
    local folder_path="$1"
    dockutil --add "$folder_path" --view fan --display stack --sort dateadded --no-restart || exit=1
}

# Add persistent-apps
# Section: Finder
echo "adding [Finder]"
addSpace
# Section: Web
addApp "/Applications/Google Chrome.app"
addApp "/Applications/ChatGPT.app"
addApp "/Applications/YT Music.app"
addSpace
# Section: Private
#addApp "/Applications/Messenger.app"
#addApp "/System/Applications/Messages.app"
#addApp "/Applications/WhatsApp.app"
#addApp "/Applications/Reolink.app"
#addSpace
# Section: Productivity
addApp "/System/Applications/Calendar.app"
addApp "/System/Applications/Reminders.app"
addApp "/System/Applications/Notes.app"
addApp "/System/Applications/Passwords.app"
addApp "/System/Applications/Utilities/Screenshot.app"
addSpace
# Section: Telekom
addApp "/Applications/Cisco/Cisco Secure Client.app"
addApp "/Applications/Microsoft Outlook.app"
addApp "/Applications/Microsoft Teams.app"
addSpace
# Section: Development
#addApp "/Applications/Slack.app"
addApp "/System/Applications/Utilities/Terminal.app"
addApp "/Applications/Fork.app"
addApp "/Applications/Visual Studio Code.app"
addApp "/Applications/Android Studio.app"
addSpace
# Section: Non pinned opened apps

# Add persistent-others
addFolder "$HOME/Downloads"

# Sleep 1 second, because quickly calling dockutil can cause issues
sleep 1

# Restart dock to apply changes
killall Dock

exit $exit
