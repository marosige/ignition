#!/usr/bin/env bash

[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# Directory Structure
###############################################################################

mkdir_withlog ~/docker                           # For Docker configuration
mkdir_withlog ~/docker/appdata                   # For Docker containers
mkdir_withlog /mnt/media/shows                   # Mount point for media shows HDD
mkdir_withlog /mnt/media/films                   # Mount point for media films HDD
mkdir_withlog /mnt/nvr                           # Mount point for NVR HDD

