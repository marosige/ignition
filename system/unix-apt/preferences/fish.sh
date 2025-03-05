#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Fish
###############################################################################

# Ensure Fish is in /etc/shells
if ! grep -wq "/usr/bin/fish" /etc/shells; then
    echo "/usr/bin/fish" | sudo tee -a /etc/shells
fi

# Set fish as the default shell for the current user
sudo chsh -s /usr/bin/fish $USER