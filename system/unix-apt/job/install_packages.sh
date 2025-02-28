#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Install applications
###############################################################################

apps=(
    "fish"            # User-friendly command-line shell for UNIX-like operating systems
    "mc"              # midnight-commander Terminal-based visual file manager
    "tldr"            # Simplified and community-driven man pages
    "thefuck"         # Programmatically correct mistyped console commands
    "wget"            # Internet file retriever
    "ffmpeg"          # Play, record, convert, and stream audio and video
    "youtube-dl"      # Download YouTube videos from the command-line
    "speedtest-cli"   # Command-line interface for https://speedtest.net bandwidth tests
    "curl"            # Command line tool for transferring data
    "btop"            # Resource monitor. C++ version and continuation of bashtop and bpytop
    "neofetch"        # Fast, highly customisable system info script
    "git"             # Version control system
    "docker.io"       #
    "docker-compose"  #
    "openssh-server"  #
)

for app in "${apps[@]}"; do
    echo -e "$IGNITION_TASK Installing $app..."
    sudo apt install -y "$app"
done

sudo apt autoremove -y && sudo apt clean
