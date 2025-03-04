#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Configuring FTP for Reolink NVR
###############################################################################

echo "Creating FTP user: reolink"
sudo adduser --disabled-password --gecos "" reolink

echo "Set a password for the reolink user:"
sudo passwd reolink

echo "Configuring FTP server..."
sed -i 's/^#write_enable=YES/write_enable=YES/' /etc/vsftpd.conf
sed -i 's/^#local_enable=YES/local_enable=YES/' /etc/vsftpd.conf
sed -i 's/^#chroot_local_user=YES/chroot_local_user=YES/' /etc/vsftpd.conf
echo "allow_writeable_chroot=YES" >> /etc/vsftpd.conf

echo "Restarting FTP service..."
systemctl restart vsftpd