#!/bin/bash
# Build and assemble TickTickBar.app (SPM executable + Info.plist bundle)
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN=.build/release/TickTickBar
APP=TickTickBar.app

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/TickTickBar"
cp ticktick.svg "$APP/Contents/Resources/"
cp Resources/ticktick-icon.png "$APP/Contents/Resources/"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>TickTickBar</string>
    <key>CFBundleIdentifier</key><string>dev.rilus.ticktickbar</string>
    <key>CFBundleName</key><string>TickTickBar</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>LSUIElement</key><true/>
    <key>CFBundleIconFile</key><string>ticktick-icon</string>
</dict>
</plist>
PLIST

echo "Built $APP"
