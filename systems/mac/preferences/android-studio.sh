#!/usr/bin/env bash

###############################################################################
# Android Studio
###############################################################################

# TODO avdmanager, sdkmanager
exit=0

# Add adb to shell
set PATH ~/Library/Android/sdk/platform-tools $PATH || exit=1

set PATH ~/bin/ignition/macOS/bin $PATH || exit=1

exit $exit
