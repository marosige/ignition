#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Configuring UFW firewall
###############################################################################

echo "Configuring UFW firewall..."
ufw allow OpenSSH  # Allow SSH
ufw allow 9091/tcp  # Transmission Web UI
ufw allow 51413/tcp  # Transmission torrent port
ufw allow 51413/udp  # Transmission UDP port
ufw allow 8096/tcp  # Jellyfin Web UI
ufw allow 21/tcp  # FTP control port
ufw allow 20/tcp  # FTP data port
ufw enable  # Enable UFW