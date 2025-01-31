#!/usr/bin/env bash

BREWFILE_PATH="/Users/gergelymarosi/workspace/personal/ignition/systems/mac/dotfiles/Brewfile"
FETCH_DESCRIPTIONS=false

# Check for --descriptions flag
if [[ "$1" == "--descriptions" ]]; then
  FETCH_DESCRIPTIONS=true
fi

# Extract formulae and casks from Brewfile
brewfile_formulae=($(grep -E '^brew "' "$BREWFILE_PATH" | awk -F'"' '{print $2}' | tr '[:upper:]' '[:lower:]'))
brewfile_casks=($(grep -E '^cask "' "$BREWFILE_PATH" | awk -F'"' '{print $2}' | tr '[:upper:]' '[:lower:]'))

# Get the list of installed formulae and casks
installed_formulae=($(brew list --formulae | tr '[:upper:]' '[:lower:]'))
installed_casks=($(brew list --casks | tr '[:upper:]' '[:lower:]'))

# Function to get description of a formula or cask
get_description() {
  local name=$1
  brew info "$name" --json=v1 | jq -r '.[0].desc'
}

# Find installed formulae not in Brewfile
echo "Installed formulae not in Brewfile:"
for formula in "${installed_formulae[@]}"; do
  if [[ ! " ${brewfile_formulae[@]} " =~ " ${formula} " ]]; then
    if $FETCH_DESCRIPTIONS; then
      description=$(get_description "$formula")
      echo "$formula - $description"
    else
      echo "$formula"
    fi
  fi
done
echo

# Find Brewfile formulae not installed
echo "Brewfile formulae not installed:"
for formula in "${brewfile_formulae[@]}"; do
  if [[ ! " ${installed_formulae[@]} " =~ " ${formula} " ]]; then
    if $FETCH_DESCRIPTIONS; then
      description=$(get_description "$formula")
      echo "$formula - $description"
    else
      echo "$formula"
    fi
  fi
done
echo

# Find installed casks not in Brewfile
echo "Installed casks not in Brewfile:"
for cask in "${installed_casks[@]}"; do
  if [[ ! " ${brewfile_casks[@]} " =~ " ${cask} " ]]; then
    if $FETCH_DESCRIPTIONS; then
      description=$(get_description "$cask")
      echo "$cask - $description"
    else
      echo "$cask"
    fi
  fi
done
echo

# Find Brewfile casks not installed
echo "Brewfile casks not installed:"
for cask in "${brewfile_casks[@]}"; do
  if [[ ! " ${installed_casks[@]} " =~ " ${cask} " ]]; then
    if $FETCH_DESCRIPTIONS; then
      description=$(get_description "$cask")
      echo "$cask - $description"
    else
      echo "$cask"
    fi
  fi
done