#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# Finder
###############################################################################

# Ensure mysides is installed
if ! command -v mysides &> /dev/null
then
	echo "$IGNITION_TASK mysides could not be found, installing..."
	brew install mysides || exit 1
fi

exit=0

# Set show file extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true || exit=1

# Set show hidden files
defaults write com.apple.finder AppleShowAllFiles -bool true || exit=1

# Set default view style to column view
defaults write com.apple.finder FXPreferredViewStyle -string clmv || exit=1

# Show path bar
defaults write com.apple.finder ShowPathbar -bool true || exit=1

# Disable the warning before emptying the Trash
defaults write com.apple.finder WarnOnEmptyTrash -bool false || exit=1

# Set keep folders on top (default)
defaults write com.apple.finder _FXSortFoldersFirst -bool false || exit=1

# Set changing file extension warning (default)
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool true || exit=1

# Set sidebar icon size to 2 (default)
defaults write NSGlobalDomain NSTableViewDefaultSizeMode -int 2 || exit=1

# Search scope
# This Mac       : `SCev`
# Current Folder : `SCcf`
# Previous Scope : `SCsp`
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf" || exit=1

# Avoid writing of .DS_Store files on network or USB volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true || exit=1
defaults write com.apple.desktopservices DSDontWriteUSBStores -bool true || exit=1

# Show the ~/Library folder
chflags nohidden ~/Library || exit=1

# New Finder windows now opens in /Users/<username>
defaults write com.apple.finder NewWindowTarget -string "PfHm" || exit=1

## Setup the sidebar
user=$(id -un)
mysides remove all || exit=1
mysides add Applications file:///Applications/ || exit=1
#mysides add Root file:///System/Volumes/Data/ || exit=1
mysides add "~" file:///Users/$user/ || exit=1
mysides add workspace file:///Users/$user/workspace/ || exit=1
mysides add tmp file:///Users/$user/tmp/ || exit=1
mysides add Desktop file:///Users/$user/Desktop/ || exit=1
mysides add Downloads file:///Users/$user/Downloads/ || exit=1

# Restart finder to apply changes
killall Finder

exit $exit
