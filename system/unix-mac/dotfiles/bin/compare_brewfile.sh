#!/usr/bin/env bash

BREWFILE_PATH="$HOME/Brewfile"
FETCH_DESCRIPTIONS=false
UNINSTALL=false

# Check for --descriptions and --uninstall flags
for arg in "$@"; do
  case $arg in
    --descriptions)
      FETCH_DESCRIPTIONS=true
      echo "Fetching descriptions can take a long time, run it without --descriptions for a fast listing."
      ;;
    --uninstall)
      UNINSTALL=true
      echo "Uninstalling formulae and casks not in Brewfile."
      ;;
    *)
      echo "Run with --descriptions to fetch descriptions for formulae and casks."
      echo "Run with --uninstall to uninstall formulae and casks not in Brewfile."
      ;;
  esac
done

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
  while IFS= read -r line; do
    name=$(echo "$line" | jq -r '.name')
    desc=$(echo "$line" | jq -r '.desc // "No description available"')
    formula_descriptions["$name"]="$desc"
  done < <(brew info --json=v2 --installed --formulae | jq -c '.formulae[]')

  while IFS= read -r line; do
    name=$(echo "$line" | jq -r '.name')
    desc=$(echo "$line" | jq -r '.desc // "No description available"')
    cask_descriptions["$name"]="$desc"
  done < <(brew info --json=v2 --installed --casks | jq -c '.casks[]')
fi

get_description() {
  local name=$1
  local type=$2

  if [[ "$type" == "cask" ]]; then
    echo "${cask_descriptions[$name]:-No description available}"
  else
    echo "${formula_descriptions[$name]:-No description available}"
  fi
}

is_in_array() {
  local item=$1
  shift
  for element in "$@"; do
    [[ "$element" == "$item" ]] && return 0
  done
  return 1
}

uninstall_items() {
  local type=$1
  shift
  local installed_items=("$@")
  local brewfile_items=("${!2}")

  for item in "${installed_items[@]}"; do
    if ! is_in_array "$item" "${brewfile_items[@]}"; then
      read -p "Uninstall $type: $item? (y/n) " choice
      [[ "$choice" == "y" ]] && brew uninstall --"$type" "$item"
    fi
  done
}

echo "Installed formulae not in Brewfile:"
for formula in "${installed_formulae[@]}"; do
  if ! is_in_array "$formula" "${brewfile_formulae[@]}"; then
    echo "$formula - $(get_description "$formula" "formula")"
  fi
done
echo

echo "Brewfile formulae not installed:"
for formula in "${brewfile_formulae[@]}"; do
  if ! is_in_array "$formula" "${installed_formulae[@]}"; then
    echo "$formula - $(get_description "$formula" "formula")"
  fi
done
echo

echo "Installed casks not in Brewfile:"
for cask in "${installed_casks[@]}"; do
  if ! is_in_array "$cask" "${brewfile_casks[@]}"; then
    echo "$cask - $(get_description "$cask" "cask")"
  fi
done
echo

echo "Brewfile casks not installed:"
for cask in "${brewfile_casks[@]}"; do
  if ! is_in_array "$cask" "${installed_casks[@]}"; then
    echo "$cask - $(get_description "$cask" "cask")"
  fi
done
echo

if $UNINSTALL; then
  uninstall_items "formula" "${installed_formulae[@]}" brewfile_formulae[@]
  uninstall_items "cask" "${installed_casks[@]}" brewfile_casks[@]
fi
