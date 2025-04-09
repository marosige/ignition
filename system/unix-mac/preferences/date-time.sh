#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# Date & Time
###############################################################################
exit=0

# Set the timezone (see `systemsetup -listtimezones` for other values)
sudo systemsetup -settimezone "Europe/Budapest" >/dev/null 2>&1 || exit=1

# Set date and time automatically
sudo systemsetup -setusingnetworktime on >/dev/null 2>&1 || exit=1

# Set time server
sudo systemsetup -setnetworktimeserver "time.apple.com" >/dev/null 2>&1 || exit=1

# Set time zome automatically using current location
sudo defaults write /Library/Preferences/com.apple.timezone.auto.plist Active -bool true || exit=1

# Clock type
# Digital: false
# Analog: true
defaults write com.apple.menuextra.clock IsAnalog -bool false || exit=1

# Clock time separators
# Flashing: true
# Static: false
defaults write com.apple.menuextra.clock FlashDateSeparators -bool false || exit=1

# Menubar digital clock format
# Default: "h:mm"
# 24-hour clock: HH
# 12-hour clock: h
# Show AM/PM: a
# Minutes: mm
# Seconds: ss
# 3-letter day of the week: EEE
# Day of the month: d
# 3-letter month: MMM
defaults write com.apple.menuextra.clock DateFormat -string "\"MMM d EEE HH:mm\"" || exit=1

exit $exit
