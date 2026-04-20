#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="ccSwitchboardMac"
PRODUCT_NAME="ccSwitch"
BUILD_DIR="$ROOT_DIR/.build"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$PRODUCT_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE_PATH="$BUILD_DIR/arm64-apple-macosx/release/$APP_NAME"
DMG_PATH="$DIST_DIR/${PRODUCT_NAME}-macos-unsigned.dmg"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

swift build -c release

cp "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"

# Generate app icon
swift "$ROOT_DIR/scripts/generate_icon.swift" "$RESOURCES_DIR"
iconutil --convert icns --output "$RESOURCES_DIR/AppIcon.icns" "$RESOURCES_DIR/AppIcon.iconset"
rm -rf "$RESOURCES_DIR/AppIcon.iconset"
chmod +x "$MACOS_DIR/$APP_NAME"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleDisplayName</key>
    <string>ccSwitch</string>
    <key>CFBundleExecutable</key>
    <string>ccSwitchboardMac</string>
    <key>CFBundleIdentifier</key>
    <string>com.eiis.ccswitch</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleName</key>
    <string>ccSwitch</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.1.4</string>
    <key>CFBundleVersion</key>
    <string>4</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

codesign --force --deep -s - "$APP_DIR"

rm -f "$DMG_PATH"

# Create DMG with Applications symlink for drag-to-install
DMG_STAGING="$DIST_DIR/dmg_staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_DIR" "$DMG_STAGING/"
ln -s /Applications "$DMG_STAGING/Applications"

hdiutil create -volname "$PRODUCT_NAME" \
    -srcfolder "$DMG_STAGING" \
    -ov -format UDZO \
    "$DMG_PATH"

rm -rf "$DMG_STAGING"

echo "App bundle: $APP_DIR"
echo "DMG package: $DMG_PATH"
