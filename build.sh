#!/bin/zsh
# Builds Parked.app (universal: Apple Silicon + Intel) and installs it to ~/Applications.
#   ./build.sh            build + install
#   ./build.sh --release  build + zip to build/Parked-<version>.zip (no install)
set -euo pipefail
cd "$(dirname "$0")"

VERSION="1.1"
BUILD_FLAGS=(-c release --arch arm64 --arch x86_64)

swift build "${BUILD_FLAGS[@]}"
BIN_DIR="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)"

APP="build/Parked.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Parked" "$APP/Contents/MacOS/Parked"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Parked</string>
    <key>CFBundleDisplayName</key><string>Parked</string>
    <key>CFBundleIdentifier</key><string>local.parked.questions</string>
    <key>CFBundleExecutable</key><string>Parked</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>VERSION_PLACEHOLDER</string>
    <key>CFBundleVersion</key><string>VERSION_PLACEHOLDER</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

sed -i '' "s/VERSION_PLACEHOLDER/$VERSION/g" "$APP/Contents/Info.plist"
codesign --force --sign - "$APP"

if [[ "${1:-}" == "--release" ]]; then
    ZIP="build/Parked-$VERSION.zip"
    rm -f "$ZIP"
    ditto -c -k --keepParent "$APP" "$ZIP"
    echo "Packaged $ZIP"
    exit 0
fi

mkdir -p ~/Applications
pkill -x Parked 2>/dev/null || true
rm -rf ~/Applications/Parked.app
cp -R "$APP" ~/Applications/
echo "Installed to ~/Applications/Parked.app"
