#!/bin/zsh
# Builds Parked.app and installs it to ~/Applications.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release

APP="build/Parked.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/Parked "$APP/Contents/MacOS/Parked"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Parked</string>
    <key>CFBundleDisplayName</key><string>Parked</string>
    <key>CFBundleIdentifier</key><string>local.parked.questions</string>
    <key>CFBundleExecutable</key><string>Parked</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP"

mkdir -p ~/Applications
pkill -x Parked 2>/dev/null || true
rm -rf ~/Applications/Parked.app
cp -R "$APP" ~/Applications/
echo "Installed to ~/Applications/Parked.app"
