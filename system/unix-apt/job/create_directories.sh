#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Directory Structure
###############################################################################

mkdir_withlog ~/docker                           # For Docker containers
mkdir_withlog ~/docker/transmission/config       # For Transmission configuration
mkdir_withlog ~/docker/transmission/downloads    # For Transmission downloads
mkdir_withlog ~/docker/jellyfin/config           # For Jellyfin configuration
mkdir_withlog ~/docker/jellyfin/media            # For Jellyfin media