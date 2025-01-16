#!/usr/bin/env bash

check_superuser() {
  if ((EUID != 0)); then
    echo >&2 "Error: script not running as root or with sudo! Exiting..."
    exit 1
  fi
}

install_software() {
  sudo apt install fish -y
  sudo apt install mc -y

  sudo apt install neofetch -y

  curl https://repo.jellyfin.org/install-debuntu.sh | sudo bash

  sudo apt-get install curl
  curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
  sudo apt-get install speedtest -y
  sudo apt install youtube-dl
  sudo apt install network-manager # for nmtui wifi connect
  sudo apt install nfs-common # for NFS nas mount - https://linuxhint.com/ubuntu_mounting_nfs/
  sudo apt install mkvtoolnix # Matroska media files manipulation tools
}

close_lid_do_nothing() {
  clear
  echo "If you are using a laptop, it's recommended to set the HandleLidSwitch configs"
  echo "A config file will open. Find HandleLidSwitch, HandleLidSwitchExternalPower, HandleLidSwitchDocked"
  echo "Remove the comment # from these lines"
  echo "Set the value to ignore"
  echo "example: HandleLidSwitch=ignore"
  echo "When done save and exit the file with ctrl + x"
  echo "Save y to save modifier buffer, then press enter to acknowledge the file name to wrie"
  read -p "Is it a laptop? [Y/n] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
  then
    sudo nano /etc/systemd/logind.conf
  fi
}

apply_settings() {
  # set fish as your default shell
  chsh -s $(which fish)

  close_lid_do_nothing

  # configure firewall for transmision
  sudo ufw allow 9091,51413/tcp

  # Mount harddrive
  # sudo fdisk -l
  sudo mount -t ntfs /dev/sdb1 /media

}

open_software() {
  neofetch
  fish
}

update_upgrade() {
  read -p "Do you want to update then upgrade? [Y/n] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
  then
    sudo apt update
    sudo apt upgrade
  fi
}

reboot() {
  echo "A system reboot is required."
  read -p "Do you want to reboot? [Y/n] " response
  if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
  then
    sudo reboot
  fi
}

echo "This script will install a bunch of software and change some settings"
read -p "Do you want to continue? [Y/n] " response
if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]
then
  check_superuser
  #install_software
  apply_settings
  open_software
  update_upgrade
  reboot
  echo "Your server is now configured!"
else
  echo "Installation cancelled."
fi
