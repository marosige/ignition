#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Directory Structure
###############################################################################

mkdir_withlog -p ~/docker/transmission/config       # For Transmission configuration
mkdir_withlog -p ~/docker/transmission/downloads    # For Transmission downloads
mkdir_withlog -p ~/docker/jellyfin/config           # For Jellyfin configuration
mkdir_withlog -p ~/docker/jellyfin/media            # For Jellyfin media