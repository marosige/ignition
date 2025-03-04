#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Configuring FTP for Reolink NVR
###############################################################################

echo -e "$IGNITION_WARN Skipping FTP setup now..."
exit 0

echo -e "$IGNITION_TASK Creating FTP user: reolink"
sudo adduser --disabled-password --gecos "" reolink

echo -e "$IGNITION_TASK Set a password for the reolink user:"
sudo passwd reolink

echo -e "$IGNITION_TASK Configuring FTP server..."
sed -i 's/^#write_enable=YES/write_enable=YES/' /etc/vsftpd.conf
sed -i 's/^#local_enable=YES/local_enable=YES/' /etc/vsftpd.conf
sed -i 's/^#chroot_local_user=YES/chroot_local_user=YES/' /etc/vsftpd.conf
echo "allow_writeable_chroot=YES" >> /etc/vsftpd.conf

echo -e "$IGNITION_TASK Restarting FTP service..."
systemctl restart vsftpd