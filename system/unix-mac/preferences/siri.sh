#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# Siri
###############################################################################
exit=0

# Enable Siri
defaults write com.apple.assistant.support "Assistant Enabled" -bool false || exit=1

# Language
defaults write com.apple.assistant.backedup "Session Language" -string "en-US" || exit=1

# Voice Feedback
# 2 : On
# 3 : Off
defaults write com.apple.assistant.backedup "Use device speaker for TTS" -int 3 || exit=1

# Keybord shortcut
# 0 : Off
# 2 : Hold Command Space
# 3 : Hold Option Space
# 4 : Press Fn (Function) Space
# 7 : Customize
defaults write com.apple.Siri HotkeyTag -int 0 || exit=1
# defaults write com.apple.Siri CustomizedKeyboardShortcut

# Show Siri in menu bar
defaults write com.apple.Siri StatusMenuVisible -bool false || exit=1

exit $exit
