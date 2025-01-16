#!/usr/bin/env bash

###############################################################################
# Safari
###############################################################################
exit=0

# Show full website address in Safari
# On: true
# Off: False
sudo defaults write com.apple.Safari ShowFullURLInSmartSearchField -bool true || exit=1

exit $exit
