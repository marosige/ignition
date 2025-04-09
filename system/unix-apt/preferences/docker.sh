#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# Configuring Docker
###############################################################################

echo -e "$IGNITION_TASK Enabling and starting Docker..."
sudo systemctl enable --now docker

echo -e "$IGNITION_TASK Starting Docker Compose..."
sudo docker-compose -f "$HOME/docker/docker-compose.yml" up -d

if ! groups $USER | grep -q "\bdocker\b"; then
    echo -e "$IGNITION_TASK Adding $USER to docker group..."
    sudo usermod -aG docker $USER
    echo -e "$IGNITION_WARN Please log out and log back in to apply the group changes."
fi