#!/usr/bin/env bash
[ -z "$IGNITION_ROOT" ] && source ~/.ignition/ignition/bootstrap.sh

###############################################################################
# Visual Studio Code Settings
###############################################################################

echo -e "$IGNITION_WARN Skipping Visual Studio Code setup now..."
exit 0

## Extensions
# Bash IDE (Autocompletion & linting)
code --install-extension mads-hartmann.bash-ide-vscode
# ShellCheck (Finds script errors & best practices)
code --install-extension timonwong.shellcheck
# Bash Beautify (Formats Bash scripts)
code --install-extension slevesque.sh-beautify

## One Dark Theme
# Install
code --install-extension zhuangtongfa.Material-theme
# Set theme
osascript -e 'tell application "Visual Studio Code" to activate' && code --install-extension zhuangtongfa.Material-theme && echo '{ "workbench.colorTheme": "One Dark Pro" }' > "$HOME/Library/Application Support/Code/User/settings.json"