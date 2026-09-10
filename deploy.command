#!/bin/bash
set -e
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="DeepSeekCostWidget"
BUILD_DIR="$PROJECT_DIR/.build"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
DMG_PATH="$BUILD_DIR/$APP_NAME.dmg"
DEST_DMG="/Users/maoge/Desktop/$APP_NAME.dmg"

cd "$PROJECT_DIR"
echo "🔨 编译..."
xcrun swift build -c release 2>&1 | tail -3

echo "📦 组装 .app..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key><string>DeepSeekCostWidget</string>
    <key>CFBundleIdentifier</key><string>com.deepseekcostwidget.app</string>
    <key>CFBundleName</key><string>DeepSeekCostWidget</string>
    <key>CFBundleDisplayName</key><string>DeepSeek 费用</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleVersion</key><string>1.0.0</string>
    <key>CFBundleShortVersionString</key><string>1.0.0</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
cp "$PROJECT_DIR/.build/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/"
chmod +x "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp "$PROJECT_DIR/Sources/DeepSeekCostWidget/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
codesign --force --deep --sign - "$APP_BUNDLE" 2>/dev/null || true

echo "💿 制作 DMG..."
rm -f "$DMG_PATH" "$DEST_DMG"
TMP_DMG="$BUILD_DIR/dmg_temp"
rm -rf "$TMP_DMG"; mkdir -p "$TMP_DMG"
cp -R "$APP_BUNDLE" "$TMP_DMG/"
hdiutil create -volname "DeepSeekCostWidget" -srcfolder "$TMP_DMG" -fs HFS+ -format UDZO "$DMG_PATH" 2>&1 | tail -1
rm -rf "$TMP_DMG"
cp "$DMG_PATH" "$DEST_DMG"
echo "✅ DMG → 桌面"
