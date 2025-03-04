#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Update apt and install applications
###############################################################################

echo "Installing dependencies..."
apt=(
  "fish"            # User-friendly command-line shell for UNIX-like operating systems
  "mc"              # Midnight Commander: Terminal-based visual file manager
  "tldr"            # Simplified and community-driven man pages
  "thefuck"         # Programmatically correct mistyped console commands
  "curl"            # Command line tool for transferring data
  "wget"            # Internet file retriever
  "nano"            # Text editor
  "ufw"             # Uncomplicated Firewall
  "vsftpd"          # FTP server
  "ffmpeg"          # Play, record, convert, and stream audio and video
  "youtube-dl"      # Download YouTube videos from the command-line
  "speedtest-cli"   # Command-line interface for https://speedtest.net bandwidth tests
  "btop"            # Resource monitor. C++ version and continuation of bashtop and bpytop
  "neofetch"        # Fast, highly customisable system info script
  "gum"             # Tool for glamorous shell scripts
  "git"             # Version control system
  "openssh-server"  # OpenSSH server for remote access
)
sudo apt install -y "${apt[@]}"

echo "Installing Docker..."
apt install -y docker.io docker-compose