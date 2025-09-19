#!/bin/bash

# Define variables
FTP_USER="reolinknvr"
FTP_GROUP="ftpusers"
FTP_PASS="ReoLinkSecurePass"  # Change this password!
FTP_ROOT="/home/$FTP_USER/ftp"
VSFTPD_CONF_DIR="/etc/vsftpd"
VSFTPD_CONF_FILE="$VSFTPD_CONF_DIR/vsftpd.conf"
VSFTPD_TARGET="/etc/vsftpd.conf"
CERT_DIR="/etc/ssl/private"
CERT_FILE="$CERT_DIR/vsftpd.pem"

echo "Updating system packages..."
sudo apt update && sudo apt install -y vsftpd openssl curl

# Create group if it doesn't exist
if ! getent group "$FTP_GROUP" >/dev/null; then
    echo "Creating group: $FTP_GROUP"
    sudo groupadd "$FTP_GROUP"
fi

# Create user if it doesn't exist
if ! id "$FTP_USER" >/dev/null 2>&1; then
    echo "Creating FTP user: $FTP_USER"
    sudo useradd -m -d "$FTP_ROOT" -s /usr/sbin/nologin -g "$FTP_GROUP" "$FTP_USER"
    echo "$FTP_USER:$FTP_PASS" | sudo chpasswd
else
    echo "User $FTP_USER already exists, skipping creation."
fi

# Ensure the FTP directory exists
sudo mkdir -p "$FTP_ROOT"
sudo chown -R "$FTP_USER:$FTP_GROUP" "$FTP_ROOT"
sudo chmod -R 755 "$FTP_ROOT"

# Generate SSL certificate if not exists
if [ ! -f "$CERT_FILE" ]; then
    echo "Generating SSL certificate for FTPS..."
    sudo mkdir -p "$CERT_DIR"
    sudo openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -keyout "$CERT_FILE" -out "$CERT_FILE" \
      -subj "/C=US/ST=State/L=City/O=Organization/OU=Department/CN=ftps-server"
    sudo chmod 600 "$CERT_FILE"
else
    echo "SSL certificate already exists, skipping generation."
fi

# Ensure vsftpd config directory exists
sudo mkdir -p "$VSFTPD_CONF_DIR"

# Copy vsftpd.conf if it does not already exist
if [ ! -f "$VSFTPD_CONF_FILE" ]; then
    echo "Creating vsftpd.conf..."
    cat <<EOF | sudo tee "$VSFTPD_CONF_FILE" > /dev/null
listen=YES
listen_ipv6=NO
anonymous_enable=NO
local_enable=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
use_localtime=YES
xferlog_enable=YES
connect_from_port_20=YES
ftpd_banner=Welcome to Reolink NVR FTP Server
chroot_local_user=YES
allow_writeable_chroot=YES

# SSL settings for FTPS
ssl_enable=YES
rsa_cert_file=$CERT_FILE
rsa_private_key_file=$CERT_FILE
force_local_logins_ssl=YES
force_local_data_ssl=YES
ssl_tlsv1=YES
ssl_sslv2=NO
ssl_sslv3=NO

# Passive mode settings
pasv_enable=YES
pasv_min_port=40000
pasv_max_port=50000
pasv_address=$(curl -s ifconfig.me) # Use external IP address for passive mode
EOF
else
    echo "vsftpd.conf already exists, skipping creation."
fi

# Ensure vsftpd.conf is placed in the correct location
if [ ! -f "$VSFTPD_TARGET" ]; then
    echo "Copying vsftpd.conf to $VSFTPD_TARGET..."
    sudo cp "$VSFTPD_CONF_FILE" "$VSFTPD_TARGET"
else
    echo "vsftpd.conf already exists in $VSFTPD_TARGET, skipping copy."
fi

# Restart vsftpd service
echo "Restarting vsftpd..."
sudo systemctl restart vsftpd
sudo systemctl enable vsftpd

# Firewall configuration for FTPS
echo "Configuring firewall to allow FTPS connections..."
sudo ufw allow 21
sudo ufw allow 40000:50000/tcp

echo "FTPS server setup complete!"
echo "Use these credentials in your Reolink camera settings:"
echo "FTP Server: $(curl -s ifconfig.me)"
echo "Username: $FTP_USER"
echo "Password: $FTP_PASS"
echo "Port: 21 (Explicit FTPS)"