#!/usr/bin/env bash

# Download .env.sh if IGNITION_MAC is not set or is empty
if [ -z "${IGNITION_MAC+x}" ]; then
  source <(curl -s https://raw.githubusercontent.com/marosige/I-like-it-like-that/main/dotfiles/env/.env.sh)
fi

cd $IGNITION_MAC
source ./print.sh

###############################################################################
# Update everything (ignition, homebrew, mas and macOS)
###############################################################################

# If not on macOS, exit.
if [ "$(uname -s)" != "Darwin" ]; then
  fail "This script is only available for macOS! Exiting..."
	exit 0
fi

info "Updating everything:"

t "Updating ignition"
cd $IGNITION_ROOT
git pull

t "Updating homebrew"
brew update
t "Upgrading homebrew"
brew upgrade
t "Installing Brewfile's dependencies"
brew bundle check --file=$BREWFILE

t "Updating Mac App Store applications"
mas upgrade

t "Updating macOS"
softwareupdate --install --all #--restart

success "Update compleated!"
