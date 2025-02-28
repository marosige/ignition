#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Configuring SSH
###############################################################################
exit=0

# This sets something
sudo systemctl enable ssh || exit=1

# This sets something
sudo systemctl start ssh || exit=1

exit $exit
