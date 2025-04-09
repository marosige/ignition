#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# Install Packages
###############################################################################

echo -e "$IGNITION_TASK Installing Homebrew Applications..."

# Request sudo access upfront
sudo -v
while true; do sudo -n true; sleep 60; done 2>/dev/null &
KEEP_ALIVE_PID=$!
trap 'kill "$KEEP_ALIVE_PID"' EXIT

# Install Homebrew if not installed
if ! hash brew 2>/dev/null; then
  echo -e "$IGNITION_TASK Homebrew not found. Installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  
  # On M1 Macs, Homebrew installs to /opt/homebrew, so we directly use it.
  if [[ -d "/opt/homebrew/bin" ]]; then
    # Source Homebrew immediately, in case this is run without restarting the shell
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi
fi

# Ensure Homebrew is up-to-date
brew update

# Upgrade existing packages
brew upgrade

# Install Homebrew packages from all Brewfiles
for brewfile in "$HOME"/Brewfile.*; do
  if [[ -f "$brewfile" ]]; then
    echo -e "$IGNITION_TASK Installing from $brewfile"
    brew bundle --file="$brewfile"
  fi
done

# Clean up outdated versions from the cellar, including casks
brew cleanup