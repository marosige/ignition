#!/usr/bin/env bash

###############################################################################
# Fish
###############################################################################
exit=0

addIfMissing () {
  if ! grep -wq $1 /etc/shells; then
      echo $1 | sudo tee -a /etc/shells
  fi
}

# Add fish into /etc/shells if missing. (Homebrew bug)
addIfMissing "/usr/local/bin/fish" || exit=1
addIfMissing "/opt/homebrew/bin/fish" || exit=1

# Set fish as default shell for the current user
sudo chsh -s $(which fish) || exit=1

exit $exit
