#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# Install Packages
###############################################################################

# On arm architecture (M1/M2), Rosetta is required for x86_64 binaries
if [[ "$(uname -m)" == "arm64" ]]; then
  echo -e "$IGNITION_TASK Installing Rosetta..."
  softwareupdate --install-rosetta --agree-to-license
fi

echo -e "$IGNITION_TASK Installing Homebrew Applications..."

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