#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Configuring Docker
###############################################################################
exit=0

# This sets something
sudo systemctl enable docker || exit=1

# This sets something
sudo docker-compose -f "$HOME/docker/docker-compose.yml" up -d || exit=1

exit $exit
