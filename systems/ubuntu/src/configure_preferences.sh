#!/usr/bin/env bash

echo -e "$IGNITION_TASK Configuring SSH..."
sudo systemctl enable ssh
sudo systemctl start ssh

if grep -q open /proc/acpi/button/lid/*/state; then
  echo "$IGNITION_TASK Configuring laptop to run with lid closed"
  sudo sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/' /etc/systemd/logind.conf
  sudo systemctl restart systemd-logind
fi

echo "$IGNITION_TASK Configuring Docker..."
sudo systemctl enable docker
sudo docker-compose -f "$HOME/docker/docker-compose.yml" up -d

