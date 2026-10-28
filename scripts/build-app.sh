#!/usr/bin/env bash
# Builds build/Ignition.app (Swift 6.2 on macOS 26; UNIVERSAL=1 needs full Xcode).
set -euo pipefail
cd "$(dirname "$0")/.."

# Universal binaries need Xcode (xcbuild); by default build for this Mac only.
ARCHS=()
if [ "${UNIVERSAL:-0}" = "1" ]; then ARCHS=(--arch arm64 --arch x86_64); fi

swift build -c release ${ARCHS[@]+"${ARCHS[@]}"}
BIN="$(swift build -c release ${ARCHS[@]+"${ARCHS[@]}"} --show-bin-path)/Ignition"

APP="build/Ignition.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Ignition"
cp -R seed "$APP/Contents/Resources/Seed"

# App icon: Resources/AppIcon.png (regenerate with scripts/make-icon.py) -> .icns
ICONSET="$(mktemp -d)/AppIcon.iconset"
mkdir -p "$ICONSET"
for size in 16 32 128 256 512; do
  sips -z $size $size Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}.png" >/dev/null
  sips -z $((size * 2)) $((size * 2)) Resources/AppIcon.png --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>Ignition</string>
  <key>CFBundleDisplayName</key><string>Ignition</string>
  <key>CFBundleIdentifier</key><string>hu.marosige.ignition</string>
  <key>CFBundleExecutable</key><string>Ignition</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${IGNITION_VERSION:-1.0.0}</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>26.0</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSAppleEventsUsageDescription</key><string>Ignition uses Terminal and System Events to set up your Mac.</string>
</dict>
</plist>
PLIST

codesign --force --deep --sign - "$APP"
echo "Built $APP"
