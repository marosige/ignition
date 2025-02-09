#!/usr/bin/env bash

###############################################################################
# System
###############################################################################
exit=0

# Set computer name
sudo scutil --set ComputerName "gengar" || exit=1
sudo scutil --set LocalHostName "gengar" || exit=1

exit $exit
