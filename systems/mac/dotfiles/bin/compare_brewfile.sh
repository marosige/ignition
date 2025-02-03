#!/usr/bin/env bash

BREWFILE_PATH="$HOME/Brewfile"
FETCH_DESCRIPTIONS=false

# Check for --descriptions flag
if [[ "$1" == "--descriptions" ]]; then
  FETCH_DESCRIPTIONS=true
  echo -e "Fetching descriptions can take a long time, run it without --descriptions for a fast listing.\n"
else
  echo -e "Run with --descriptions to fetch descriptions for formulae and casks.\n"
fi

# Extract formulae and casks from Brewfile
mapfile -t brewfile_formulae < <(grep -E '^brew "' "$BREWFILE_PATH" | awk -F'"' '{print $2}' | tr '[:upper:]' '[:lower:]')
mapfile -t brewfile_casks < <(grep -E '^cask "' "$BREWFILE_PATH" | awk -F'"' '{print $2}' | tr '[:upper:]' '[:lower:]')

# Get the list of installed formulae and casks
mapfile -t installed_formulae < <(brew list --formulae | tr '[:upper:]' '[:lower:]')
mapfile -t installed_casks < <(brew list --casks | tr '[:upper:]' '[:lower:]')

declare -A formula_descriptions
declare -A cask_descriptions

# Fetch all installed formulae and cask descriptions in bulk
if $FETCH_DESCRIPTIONS; then  
  # Fetch installed formulae descriptions
  while IFS= read -r line; do
    name=$(echo "$line" | jq -r '.name')
    desc=$(echo "$line" | jq -r '.desc // "No description available"')
    formula_descriptions["$name"]="$desc"
  done < <(brew info --json=v2 --installed --formulae | jq -c '.formulae[]')

  # Fetch installed casks descriptions
  while IFS= read -r line; do
    name=$(echo "$line" | jq -r '.name')
    desc=$(echo "$line" | jq -r '.desc // "No description available"')
    cask_descriptions["$name"]="$desc"
  done < <(brew info --json=v2 --installed --casks | jq -c '.casks[]')
fi

# Function to get description from dictionary or fetch missing ones in bulk
get_description() {
  local name=$1
  local type=$2

  if [[ "$type" == "cask" ]]; then
    [[ -n "${cask_descriptions[$name]}" ]] && echo "${cask_descriptions[$name]}" && return
  else
    [[ -n "${formula_descriptions[$name]}" ]] && echo "${formula_descriptions[$name]}" && return
  fi

  if $FETCH_DESCRIPTIONS; then
    if [[ "$type" == "cask" ]]; then
      # Try JSON first
      desc=$(brew info --json=v2 --cask "$name" 2>/dev/null | jq -r '.casks[0].desc // empty')

      # If JSON fails, extract from plain brew info output
      if [[ -z "$desc" ]]; then
        desc=$(brew info "$name" | grep -E "^[[:alnum:]].+:" | head -n 1 | sed 's/^[^:]*: //')
      fi
    else
      # Formula (JSON should work fine)
      desc=$(brew info --json=v2 "$name" 2>/dev/null | jq -r '.formulae[0].desc // "No description available"')
    fi

    [[ -z "$desc" ]] && desc="No description available"
    [[ "$type" == "cask" ]] && cask_descriptions["$name"]="$desc" || formula_descriptions["$name"]="$desc"
    echo "$desc"
  else
    echo "No description available"
  fi
}

# Function to check if an item is in an array
is_in_array() {
  local item=$1
  shift
  for element in "$@"; do
    if [[ "$element" == "$item" ]]; then
      return 0
    fi
  done
  return 1
}

# Find installed formulae not in Brewfile
echo "Installed formulae not in Brewfile:"
for formula in "${installed_formulae[@]}"; do
  if ! is_in_array "$formula" "${brewfile_formulae[@]}"; then
    if $FETCH_DESCRIPTIONS; then
      echo "$formula - $(get_description "$formula" "formula")"
    else
      echo "$formula"
    fi
  fi
done
echo

# Find Brewfile formulae not installed
echo "Brewfile formulae not installed:"
missing_formulae=()
for formula in "${brewfile_formulae[@]}"; do
  if ! is_in_array "$formula" "${installed_formulae[@]}"; then
    missing_formulae+=("$formula")
  fi
done

# Batch fetch missing formula descriptions
if $FETCH_DESCRIPTIONS && [[ ${#missing_formulae[@]} -gt 0 ]]; then
  while IFS= read -r line; do
    name=$(echo "$line" | jq -r '.name')
    desc=$(echo "$line" | jq -r '.desc // "No description available"')
    formula_descriptions["$name"]="$desc"
  done < <(brew info --json=v2 "${missing_formulae[@]}" 2>/dev/null | jq -c '.formulae[]')
fi

for formula in "${missing_formulae[@]}"; do
  echo "$formula - $(get_description "$formula" "formula")"
done
echo

# Find installed casks not in Brewfile
echo "Installed casks not in Brewfile:"
for cask in "${installed_casks[@]}"; do
  if ! is_in_array "$cask" "${brewfile_casks[@]}"; then
    if $FETCH_DESCRIPTIONS; then
      echo "$cask - $(get_description "$cask" "cask")"
    else
      echo "$cask"
    fi
  fi
done
echo

# Find Brewfile casks not installed
echo "Brewfile casks not installed:"
missing_casks=()
for cask in "${brewfile_casks[@]}"; do
  if ! is_in_array "$cask" "${installed_casks[@]}"; then
    missing_casks+=("$cask")
  fi
done

# Batch fetch missing cask descriptions
if $FETCH_DESCRIPTIONS && [[ ${#missing_casks[@]} -gt 0 ]]; then
  while IFS= read -r line; do
    name=$(echo "$line" | jq -r '.name')
    desc=$(echo "$line" | jq -r '.desc // "No description available"')
    cask_descriptions["$name"]="$desc"
  done < <(brew info --json=v2 --cask "${missing_casks[@]}" 2>/dev/null | jq -c '.casks[]')
fi

for cask in "${missing_casks[@]}"; do
  if $FETCH_DESCRIPTIONS; then
      echo "$cask - $(get_description "$cask" "cask")"
    else
      echo "$cask"
    fi
done