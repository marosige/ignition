#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# Install Packages
###############################################################################

echo -e "$IGNITION_TASK Installing Homebrew Applications..."

# Install Homebrew if not installed - brew.sh
if ! hash brew 2>/dev/null; then
  echo -e "$IGNITION_TASK Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Make sure we are using the latest Homebrew
brew update

# Upgrade existing packages
brew upgrade

# Install Homebrew packages from all Brewfiles
for brewfile in "$HOME/Brewfile.*"; do
  echo -e "$IGNITION_TASK Installing from $brewfile..."
  brew bundle --file="$brewfile"
done

# Remove outdated versions from the cellar including casks
brew cleanup
