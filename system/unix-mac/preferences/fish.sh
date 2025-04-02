#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

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
chsh -s "$(which fish)" >/dev/null 2>&1 || exit=1

exit $exit
