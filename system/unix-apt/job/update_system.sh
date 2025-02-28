#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Update system
###############################################################################

# Update package list and upgrade all packages
sudo apt-get update
sudo apt-get upgrade -y
