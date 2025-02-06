#!/usr/bin/env bash

###############################################################################
# Configuring SSH
###############################################################################
exit=0

# This sets something
sudo systemctl enable ssh || exit=1

# This sets something
sudo systemctl start ssh || exit=1

exit $exit
