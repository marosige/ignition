#!/bin/bash

# Update system
echo "Updating system..."
sudo apt update && sudo apt upgrade -y

# Install necessary packages
echo "Installing necessary packages..."
sudo apt install -y docker.io docker-compose openssh-server

# Enable and start SSH service
echo "Configuring SSH..."
sudo systemctl enable ssh
sudo systemctl start ssh

# Allow laptop to operate with the lid closed
echo "Configuring system to run with lid closed..."
LID_CONF="/etc/systemd/logind.conf"
sudo sed -i '/^#HandleLidSwitch=/s/^#//' "$LID_CONF"
sudo sed -i '/^HandleLidSwitch=/s/=.*/=ignore/' "$LID_CONF"
sudo sed -i '/^#HandleLidSwitchDocked=/s/^#//' "$LID_CONF"
sudo sed -i '/^HandleLidSwitchDocked=/s/=.*/=ignore/' "$LID_CONF"
sudo systemctl restart systemd-logind

# Enable Docker to start at boot
echo "Configuring Docker..."
sudo systemctl enable docker

# Create directories
echo "Setting up directories..."
DEPLOY_DIR="$HOME/ignition"
SCRIPT_DIR=$(dirname "$(realpath "$0")")
DOCKER_COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
mkdir -p "$DEPLOY_DIR"

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
