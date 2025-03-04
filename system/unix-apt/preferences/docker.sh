#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Configuring Docker
###############################################################################

echo "Enabling and starting Docker..."
systemctl enable --now docker

echo "Starting Docker Compose..."
sudo docker-compose -f "$HOME/docker/docker-compose.yml" up -d