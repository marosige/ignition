#!/usr/bin/env bash

###############################################################################
# This script downloads ignition from GitHub with user-selected systems only.
###############################################################################

# Set installation directory
IGNITION_ROOT="$HOME/ignition"

# Exit if ignition already exists
[ -d "$IGNITION_ROOT" ] && echo "Ignition is already downloaded at $IGNITION_ROOT" && exit 1

# Check for git
command -v git &> /dev/null || {
    echo "git could not be found, please install it first."
    echo "On Ubuntu:  sudo apt install git"
    echo "On macOS:   brew install git"
    exit 1
}

# Clone repo without checkout
echo "Cloning ignition repo into $IGNITION_ROOT..."
git clone --filter=tree:0 --no-checkout https://github.com/marosige/ignition "$IGNITION_ROOT"

# Init sparse-checkout and don't checkout anything yet
git -C "$IGNITION_ROOT" sparse-checkout init --cone
git -C "$IGNITION_ROOT" sparse-checkout set ""
git -C "$IGNITION_ROOT" checkout main

# List folders inside 'system/' from git tree (not from filesystem)
cd "$IGNITION_ROOT" || exit 1

# Use a loop to populate the systems array, skip hidden folders, and sort alphabetically
systems=()
while IFS= read -r line; do
    # Skip hidden folders (starting with '.')
    if [[ "$line" != .* ]]; then
        systems+=("$line")
    fi
done < <(git ls-tree --name-only HEAD:system)

# Sort systems alphabetically
IFS=$'\n' sorted_systems=($(sort <<<"${systems[*]}"))
unset IFS

# Prompt user for selection
echo "Available systems:"
for i in "${!sorted_systems[@]}"; do
    echo "$((i+1))) ${sorted_systems[$i]}"
done

echo "Enter the numbers of the systems you want to install (e.g. 1 3 5):"
read -r -a selections

# Validate selection and build sparse-checkout list
selected_paths=("ignition") # Always include ignition
for index in "${selections[@]}"; do
    if [[ "$index" =~ ^[0-9]+$ ]] && (( index > 0 && index <= ${#sorted_systems[@]} )); then
        selected_paths+=("system/${sorted_systems[index-1]}")
    else
        echo "Invalid selection: $index"
    fi
done

# Apply final sparse-checkout set and checkout
git -C "$IGNITION_ROOT" sparse-checkout set "${selected_paths[@]}"
git -C "$IGNITION_ROOT" checkout main

# Final message
echo "✅ Ignition and selected systems installed at $IGNITION_ROOT"

# Launch ignition
read -p "Press Enter to start ignition, or Ctrl+C to exit..."
cd "$IGNITION_ROOT/ignition" || exit 1
exec bash ignition.sh