#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# Configuring UFW firewall
###############################################################################

echo -e "$IGNITION_WARN Skipping UFW setup now..."
exit 0

echo -e "$IGNITION_TASK Configuring UFW firewall..."
sudo ufw allow OpenSSH  # Allow SSH
sudo ufw allow 9091/tcp  # Transmission Web UI
sudo ufw allow 51413/tcp  # Transmission torrent port
sudo ufw allow 51413/udp  # Transmission UDP port
sudo ufw allow 8096/tcp  # Jellyfin Web UI
sudo ufw allow 21/tcp  # FTP control port
sudo ufw allow 20/tcp  # FTP data port
sudo ufw enable  # Enable UFW