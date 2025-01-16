#!/usr/bin/env bash

###############################################################################
# Security & Privacy
###############################################################################
exit=0

# Require password immediately after sleep or screen saver begins
defaults write com.apple.screensaver askForPassword -bool true || exit=1
defaults write com.apple.screensaver askForPasswordDelay -int 0 || exit=1

# Disable automatic login
#sudo defaults delete /Library/Preferences/com.apple.loginwindow autoLoginUser || exit=1

# Disable the “Are you sure you want to open this application?” dialog
defaults write com.apple.LaunchServices LSQuarantine -bool false || exit=1

# Allow applications downloaded from anywhere
sudo spctl --master-disable || exit=1

# Turn on Firewall
sudo defaults write /Library/Preferences/com.apple.alf globalstate -int 1 || exit=1

# Allow signed apps
sudo defaults write /Library/Preferences/com.apple.alf allowsignedenabled -bool true || exit=1

exit $exit
