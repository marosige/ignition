#!/usr/bin/env bash
# Installs the latest Ignition release on a fresh Mac:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/marosige/ignition/main/scripts/install.sh)"
set -euo pipefail

# Newest release, prereleases included (the "latest" shortcut skips them).
URL="$(curl -fsSL "https://api.github.com/repos/marosige/ignition/releases?per_page=5" \
  | grep -m1 '"browser_download_url".*Ignition\.zip' | sed 's/.*"\(https[^"]*\)".*/\1/')"
[ -n "$URL" ] || { echo "No Ignition release found."; exit 1; }
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading Ignition…"
curl -fsSL "$URL" -o "$TMP/Ignition.zip"
ditto -x -k "$TMP/Ignition.zip" "$TMP"
rm -rf /Applications/Ignition.app
mv "$TMP/Ignition.app" /Applications/Ignition.app
xattr -dr com.apple.quarantine /Applications/Ignition.app
echo "Installed. Opening Ignition…"
open /Applications/Ignition.app
