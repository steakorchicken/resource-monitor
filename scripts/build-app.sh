#!/bin/bash
# Builds a release binary and packages it into "build/Resource Monitor.app".
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Resource Monitor.app"

swift build -c release --arch arm64
BIN_DIR="$(swift build -c release --arch arm64 --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/ResourceMonitor" "$APP/Contents/MacOS/ResourceMonitor"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# Optional icon: used if present (generated icon is a later nicety).
if [ -f Resources/AppIcon.icns ]; then
    cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
fi

codesign --force --deep --sign - "$APP"

echo
echo "Built: $PWD/$APP"
echo "Run:   open \"$APP\""
