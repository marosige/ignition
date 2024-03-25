#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# System
###############################################################################
exit=0

# Set computer name
sudo scutil --set ComputerName "gengar" || exit=1
sudo scutil --set LocalHostName "gengar" || exit=1

exit $exit
