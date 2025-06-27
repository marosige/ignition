#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# Visual Studio Code Settings
###############################################################################

## Extensions
# Bash IDE (Autocompletion & linting)
code --install-extension mads-hartmann.bash-ide-vscode
# ShellCheck (Finds script errors & best practices)
code --install-extension timonwong.shellcheck
# Bash Beautify (Formats Bash scripts)
code --install-extension slevesque.sh-beautify
# Kotlin Language Support (Syntax highlighting, IntelliSense, debugging)
code --install-extension fwcd.kotlin
# Python extension (Linting, IntelliSense, Jupyter support)
code --install-extension ms-python.python

## One Dark Theme
# Install
code --install-extension zhuangtongfa.Material-theme
# Set theme
osascript -e 'tell application "Visual Studio Code" to activate' && code --install-extension zhuangtongfa.Material-theme