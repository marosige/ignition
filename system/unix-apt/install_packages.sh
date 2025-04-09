#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# Update apt and install applications
###############################################################################

sudo apt update
sudo apt upgrade -y

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
    "speedtest-cli"   # Command-line interface for https://speedtest.net bandwidth tests
    "btop"            # Resource monitor. C++ version and continuation of bashtop and bpytop
    "neofetch"        # Fast, highly customisable system info script
    "git"             # Version control system
    "openssh-server"  # OpenSSH server for remote access
    "docker.io"       # Docker - Official package for Docker from Ubuntu repositories
    "docker-compose"  # Docker Compose - from Ubuntu repositories (not the latest)
    "youtube-dl"      # Download YouTube videos from the command-line
    "gum"             # Tool for glamorous shell scripts
)

for app in "${apt[@]}"; do
    echo -e "$IGNITION_TASK apt installing $app..."
    sudo apt install -y "$app"
done
