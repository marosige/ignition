#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Configuring Docker
###############################################################################

echo -e "$IGNITION_TASK Enabling and starting Docker..."
sudo systemctl enable --now docker

echo -e "$IGNITION_TASK Starting Docker Compose..."
sudo docker-compose -f "$HOME/docker/docker-compose.yml" up -d