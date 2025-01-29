#!/usr/bin/env bash

###############################################################################
# This script sets up a home server ubuntu
#
# Made by Gergely Marosi - https://github.com/marosige
###############################################################################

echo -e "$IGNITION_TASK Ubuntu setup"


# Link docker-compose.yml
echo "Linking docker-compose.yml..."
if [ ! -f "$DOCKER_COMPOSE_FILE" ]; then
  echo "Error: docker-compose.yml not found in $SCRIPT_DIR."
  exit 1
fi
ln -sf "$DOCKER_COMPOSE_FILE" "$DEPLOY_DIR/docker-compose.yml"

# Adjust permissions
echo "Setting up permissions..."
mkdir -p "$DEPLOY_DIR/transmission/config" "$DEPLOY_DIR/transmission/downloads" "$DEPLOY_DIR/transmission/watch"
mkdir -p "$DEPLOY_DIR/jellyfin/config" "$DEPLOY_DIR/jellyfin/cache" "$DEPLOY_DIR/jellyfin/media"
mkdir -p "$DEPLOY_DIR/plex/config" "$DEPLOY_DIR/plex/transcode" "$DEPLOY_DIR/plex/media"
sudo chown -R 1000:1000 "$DEPLOY_DIR"

# Start Docker containers
echo "Starting Docker containers..."
cd "$DEPLOY_DIR" || exit
docker-compose up -d

# Get current username and local IP
USERNAME=$(whoami)
LOCAL_IP=$(hostname -I | awk '{print $1}')

# Display completion message
echo "Setup complete. Access services on your local network:"
echo "  - Transmission: http://$LOCAL_IP:9091"
echo "  - Jellyfin: http://$LOCAL_IP:8096"
echo "  - Plex: http://$LOCAL_IP:32400/web"
echo "You can SSH into this machine using: ssh $USERNAME@$LOCAL_IP"
