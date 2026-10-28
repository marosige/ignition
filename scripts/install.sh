#!/usr/bin/env bash
# Installs the latest Ignition release on a fresh Mac:
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/marosige/ignition/main/scripts/install.sh)"
set -euo pipefail

URL="https://github.com/marosige/ignition/releases/latest/download/Ignition.zip"
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
