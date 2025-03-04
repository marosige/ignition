#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Fish
###############################################################################
exit=0

addIfMissing () {
  # Add Fish to /etc/shells if it’s not already listed
  if ! grep -wq "$1" /etc/shells; then
      echo "$1" | sudo tee -a /etc/shells
  fi
}

# Add fish into /etc/shells if missing
addIfMissing "/usr/bin/fish" || exit=1

echo -e "$IGNITION_TASK Setting Fish as default shell..."

# Set fish as default shell for the current user
sudo chsh -s "$(which fish)" >/dev/null 2>&1 || exit=1

exit $exit