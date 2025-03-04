#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Directory Structure
###############################################################################

mkdir_withlog ~/docker                           # For Docker configuration
mkdir_withlog ~/docker/appdata                   # For Docker containers

# Set permissions
echo -e "$IGNITION_TASK Setting directory user permissions..."
sudo chmod -R 775 ~/docker
sudo chown -R $USER:$USER ~/docker