#!/usr/bin/env bash

###############################################################################
# Startup computer with these software
###############################################################################

# Delay to ensure macOS services are ready
sleep 5

# List of applications to start (modify as needed)
apps=(
    "1Password"
    "ProtonVPN"
    "MonitorControl"
    "amphetamine"
    "clipy"
    "magnet"
    "logi Options+"
)

for app in "${apps[@]}"; do
    open -a "$app"
done

echo "Auto-start applications launched."