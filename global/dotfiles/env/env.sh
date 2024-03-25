# This file is meant to compatible with multiple shells, including:
# bash, zsh and fish. For this reason, use this syntax:
#    export VARNAME=value

### Ignition locations

## Root folder
export IGNITION_ROOT="$HOME/.ignition"

## Global folders
export IGNITION_GLB="$IGNITION_ROOT/global"
export IGNITION_GLB_BIN="$IGNITION_GLB/bin"
export IGNITION_GLB_DOT="$IGNITION_GLB/dotfiles"
export IGNITION_GLB_LIBS="$IGNITION_GLB/libs"

# Libraries
export IGNITION_LIB_PRINT="$IGNITION_GLB_LIBS/print.sh"
export IGNITION_LIB_TOOLS="$IGNITION_GLB_LIBS/tools.sh"

## macOS daily driver folders
export IGNITION_MAC="$IGNITION_ROOT/macOS"
export IGNITION_MAC_BIN="$IGNITION_MAC/bin"
export IGNITION_MAC_DOT="$IGNITION_MAC/dotfiles"

# Homebrew Bundle (only macOS)
export BREWFILE="$HOME/Brewfile"

## Ubuntu server homelab folders
export IGNITION_LAB="$IGNITION_ROOT/Ubuntu"
export IGNITION_LAB_BIN="$IGNITION_LAB/bin"
export IGNITION_LAB_DOT="$IGNITION_LAB/dotfiles"

## Log files
export IGNITION_LOG_FOLDER="$IGNITION_ROOT/logs"
export IGNITION_LOG_INSTALLERS="$IGNITION_LOG_FOLDER/installers.log"
export IGNITION_LOG_PREFERENCES="$IGNITION_LOG_FOLDER/preferences.log"
