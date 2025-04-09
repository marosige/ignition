#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# Install Packages
###############################################################################

echo -e "$IGNITION_TASK Installing Homebrew Applications..."

# Install Homebrew if not installed - brew.sh
if ! hash brew 2>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Make sure we are using the latest Homebrew
brew update

# Upgrade existing packages
brew upgrade

# Install CLI tools & GUI applications
brewfile="$HOME/Brewfile"
if [ -f "$brewfile" ]; then
  brew bundle --file="$brewfile"
else
  echo -e "$IGNITION_FAIL Brewfile not found in $brewfile"
  exit 1
fi

# Remove outdated versions from the cellar including casks
brew cleanup
