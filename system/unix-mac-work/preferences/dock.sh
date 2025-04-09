#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# Dock
###############################################################################
exit=0

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
# Section: Productivity
addApp "/System/Applications/Calendar.app"
addApp "/System/Applications/Reminders.app"
addApp "/System/Applications/Notes.app"
addApp "/System/Applications/Passwords.app"
addApp "/System/Applications/Utilities/Screenshot.app"
addSpace
# Section: Telekom
addApp "/Applications/Cisco/Cisco Secure Client.app"
addApp "/Applications/Figma.app"
addApp "/Applications/Microsoft Outlook.app"
addApp "/Applications/Microsoft Teams.app"
addSpace
# Section: Development
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
