#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

APP_NAME="macnotifier"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"
BUNDLE_ID="sh.send.macnotifier"

echo "Building $APP_NAME.app..."

# Create .app bundle directory structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Generate Info.plist
cat > "$APP_BUNDLE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
</dict>
</plist>
PLIST

# Compile
swiftc \
    -swift-version 5 \
    -o "$APP_BUNDLE/Contents/MacOS/$APP_NAME" \
    "$PROJECT_DIR"/Sources/*.swift

# Copy icon if present
if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
    cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
elif [ -f "$PROJECT_DIR/Resources/macnotifier.icns" ]; then
    cp "$PROJECT_DIR/Resources/macnotifier.icns" "$APP_BUNDLE/Contents/Resources/"
fi

# Ad-hoc code signing
codesign --force --deep --sign - "$APP_BUNDLE"

echo "Built $APP_BUNDLE"
