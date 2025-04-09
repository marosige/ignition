#!/usr/bin/env bash

###############################################################################
# This script downloads ignition from GitHub with user-selected systems only.
###############################################################################

# Set installation directory
IGNITION_ROOT="$HOME/.ignition"

# Exit if ignition already exists
if [ -d "$IGNITION_ROOT" ]; then
  echo "Ignition is already downloaded at $IGNITION_ROOT"
  exit 1
fi

# Check for git
command -v git &> /dev/null || {
    echo "git is not installed. Install it with: sudo apt install git (Ubuntu) or brew install git (macOS)"
    exit 1
}

# Clone repo without checkout
echo "Cloning ignition repo into $IGNITION_ROOT..."
git clone --filter=tree:0 --no-checkout https://github.com/marosige/ignition "$IGNITION_ROOT" &>/dev/null || {
    echo "Failed to clone the repository."
    exit 1
}

# Initialize sparse-checkout
git -C "$IGNITION_ROOT" sparse-checkout init --cone &>/dev/null
git -C "$IGNITION_ROOT" sparse-checkout set "" &>/dev/null
git -C "$IGNITION_ROOT" checkout main &>/dev/null

# List system folders from git tree
cd "$IGNITION_ROOT" || exit 1

systems=()
while IFS= read -r line; do
    [[ "$line" != .* ]] && systems+=("$line")
done < <(git ls-tree --name-only HEAD:system)

# Sort systems alphabetically
IFS=$'\n' sorted_systems=($(sort <<<"${systems[*]}"))
unset IFS

# Display available systems
echo "Available systems:"
for i in "${!sorted_systems[@]}"; do
    echo "$((i+1))) ${sorted_systems[$i]}"
done

# User selects systems
echo "Enter the numbers of the systems you want to install (e.g. 1 3 5):"
read -r -a selections

# Validate selections and build paths
selected_paths=("ignition")
for index in "${selections[@]}"; do
    if [[ "$index" =~ ^[0-9]+$ ]] && (( index > 0 && index <= ${#sorted_systems[@]} )); then
        selected_paths+=("system/${sorted_systems[index-1]}")
    else
        echo "Invalid selection: $index"
    fi
done

# Apply sparse-checkout for selected systems
git -C "$IGNITION_ROOT" sparse-checkout set "${selected_paths[@]}" &>/dev/null
git -C "$IGNITION_ROOT" checkout main &>/dev/null

# Completion message
echo "✅ Ignition and selected systems installed at $IGNITION_ROOT"

# Start ignition
read -p "Press Enter to start ignition, or Ctrl+C to exit..."
cd "$IGNITION_ROOT/ignition" || exit 1
exec bash ignition.sh