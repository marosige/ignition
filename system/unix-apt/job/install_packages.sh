#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Update apt and install applications
###############################################################################

# Update package list
echo -e "$IGNITION_TASK Updating package list..."
sudo apt update

# List of APT packages to install
apt=(
    "fish"            # User-friendly command-line shell for UNIX-like operating systems
    "mc"              # Midnight Commander: Terminal-based visual file manager
    "tldr"            # Simplified and community-driven man pages
    "thefuck"         # Programmatically correct mistyped console commands
    "wget"            # Internet file retriever
    "ffmpeg"          # Play, record, convert, and stream audio and video
    "youtube-dl"      # Download YouTube videos from the command-line
    "speedtest-cli"   # Command-line interface for https://speedtest.net bandwidth tests
    "curl"            # Command line tool for transferring data
    "btop"            # Resource monitor. C++ version and continuation of bashtop and bpytop
    "neofetch"        # Fast, highly customisable system info script
    "gum"             # Tool for glamorous shell scripts
    "git"             # Version control system
    "docker.io"       # Docker
    "openssh-server"  # OpenSSH server for remote access
    "python3-pip"     # Python package installer
)

# List of pip packages to install
pip=(
    "docker-compose"  # Docker Compose via pip3
)

# Install APT packages
for app in "${apt[@]}"; do
    echo -e "$IGNITION_TASK apt installing $app..."
    sudo apt install -y "$app"
done

# Install pip packages
for app in "${pip[@]}"; do
    echo -e "$IGNITION_TASK pip installing $app..."
    sudo pip3 install --upgrade "$app"
done

# Clean up unnecessary packages and cache
echo -e "$IGNITION_TASK Cleaning up..."
sudo apt autoremove -y && sudo apt clean

echo -e "$IGNITION_DONE Setup complete."