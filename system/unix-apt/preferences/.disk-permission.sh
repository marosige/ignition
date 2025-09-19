#!/bin/bash

# Check if the script is run with root privileges
if [ "$(id -u)" -ne 0 ]; then
    echo -e "$IGNITION_ERROR This script must be run as root."
    read -p "Would you like to rerun the script with sudo? (y/n): " response
    if [[ "$response" == "y" || "$response" == "Y" ]]; then
        sudo "$0" "$@"
        exit 0
    else
        echo -e "$IGNITION_ERROR Exiting script. Please run as root or with sudo."
        exit 1
    fi
fi

# Get the currently logged-in username using $USER
USER="$USER"
HOME_DIR="/home/$USER"

# Check if the home directory exists
if [ ! -d "$HOME_DIR" ]; then
    echo -e "$IGNITION_ERROR Home directory $HOME_DIR does not exist. Exiting."
    exit 1
fi

# 1. Set Ownership of the Home Directory
echo -e "$IGNITION_TASK Setting ownership of $HOME_DIR to $USER..."
chown $USER:$USER $HOME_DIR

# 2. Set Permissions for the Home Directory
echo -e "$IGNITION_TASK Setting permissions for $HOME_DIR..."
chmod 755 $HOME_DIR

# 3. Configure vsftpd
echo -e "$IGNITION_TASK Configuring vsftpd..."

# Edit the vsftpd configuration
VSFTPD_CONF="/etc/vsftpd.conf"
if grep -q "local_enable=YES" $VSFTPD_CONF; then
    echo -e "$IGNITION_DONE vsftpd is already configured to allow local users."
else
    echo -e "$IGNITION_TASK Enabling local user access in vsftpd..."
    echo "local_enable=YES" >> $VSFTPD_CONF
fi

if grep -q "write_enable=YES" $VSFTPD_CONF; then
    echo -e "$IGNITION_DONE Write permissions are already enabled in vsftpd."
else
    echo -e "$IGNITION_TASK Enabling write permissions in vsftpd..."
    echo "write_enable=YES" >> $VSFTPD_CONF
fi

# 4. Restart vsftpd to apply changes
echo -e "$IGNITION_TASK Restarting vsftpd service..."
systemctl restart vsftpd

# 5. Final message
echo -e "$IGNITION_DONE FTP setup completed for user $USER. They can now access and modify their home directory via FTP."

# todo mnt
sudo chown -R $USER:$USER /mnt
sudo chmod 755 /mnt
