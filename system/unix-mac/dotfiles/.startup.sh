#!/usr/bin/env bash

###############################################################################
# Startup computer with these software
###############################################################################

# Delay to ensure macOS services are ready
sleep 5

# List of applications to start (modify as needed)
apps=(
    "MonitorControl"
    "amphetamine"
    "magnet"
    "logi Options+"
)

for app in "${apps[@]}"; do
    open -a "$app"
done

echo "Auto-start applications launched."

sleep 10

# Close any open Finder windows
osascript -e 'tell application "Finder" to close every window'

echo "All Finder windows closed."