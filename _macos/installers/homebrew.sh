#!/usr/bin/env bash

###############################################################################
# Homebrew
###############################################################################

exit=0

task "Installing Homebrew Applications"

# Install Homebrew if not installed - brew.sh
if ! hash brew 2>/dev/null; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" >> $log_file || exit=1
fi

# Make sure we are using the latest Homebrew
brew update >> $log_file || exit=1

# Upgrade existing packages
brew upgrade >> $log_file || exit=1

# Install CLI tools & GUI applications
brew bundle --file=~/Brewfile >> $log_file || exit=1

# Remove outdated versions from the cellar including casks
brew cleanup >> $log_file || exit=1

if $exit; then
  success "Homebrew Applications Installed"
else
  fail "There was an error during installs."
  # Use readlink to get the full path
  full_path=$(readlink -f "$log_file")
  # Print the clickable full path
  warn "Check log for error messages: file://$log_file"
fi

exit $exit
