#!/usr/bin/env bash

echo "Updating Ubuntu system..."
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y
