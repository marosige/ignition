#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/bootstrap.sh

###############################################################################
# Safari
###############################################################################
exit=0

# Show full website address in Safari
# On: true
# Off: False
sudo defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true || exit=1

exit $exit
