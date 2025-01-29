#!/usr/bin/env bash

echo "Configuring SSH..."
sudo systemctl enable ssh
sudo systemctl start ssh

echo "Configuring system to run with lid closed..."
LID_CONF="/etc/systemd/logind.conf"
sudo sed -i '/^#HandleLidSwitch=/s/^#//' "$LID_CONF"
sudo sed -i '/^HandleLidSwitch=/s/=.*/=ignore/' "$LID_CONF"
sudo sed -i '/^#HandleLidSwitchDocked=/s/^#//' "$LID_CONF"
sudo sed -i '/^HandleLidSwitchDocked=/s/=.*/=ignore/' "$LID_CONF"
sudo systemctl restart systemd-logind

echo "Configuring Docker..."
sudo systemctl enable docker
