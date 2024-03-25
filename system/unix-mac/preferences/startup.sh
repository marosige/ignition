#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Software on startup
###############################################################################

# Path to the script that will auto-start your apps
STARTUP_SCRIPT="$HOME/.startup.sh"
PLIST_PATH="$HOME/Library/LaunchAgents/com.custom.autostart.plist"

# Ensure old login items are removed
osascript -e 'tell application "System Events" to delete every login item'

# Create a LaunchAgent to run the custom script at login
cat <<EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.custom.autostart</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$STARTUP_SCRIPT</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
EOF

# Set correct permissions
chmod 644 "$PLIST_PATH"

# Unload the LaunchAgent if it is already loaded
launchctl bootout gui/$(id -u) "$PLIST_PATH" 2>/dev/null

# Load the LaunchAgent
if ! launchctl bootstrap gui/$(id -u) "$PLIST_PATH"; then
    echo -e "$IGNITION_FAIL Error: Failed to load LaunchAgent"
    exit 1
fi

echo -e "$IGNITION_DONE All auto-start apps removed. Custom script added: $STARTUP_SCRIPT"