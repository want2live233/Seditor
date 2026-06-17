#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Seditor"
PRODUCT_NAME="Seditor"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RES_DIR="$CONTENTS_DIR/Resources"
ICON_FILE="$ROOT_DIR/Assets/AppIcon.icns"
HELP_BOOK_DIR="$ROOT_DIR/Assets/HelpBook/SeditorHelp.help"

if [[ ! -f "$ICON_FILE" ]]; then
  echo "Missing icon: $ICON_FILE"
  exit 1
fi

echo "Building release binary..."
swift build -c release --product "$PRODUCT_NAME"
BIN_PATH="$(swift build -c release --show-bin-path)/$PRODUCT_NAME"

if [[ ! -x "$BIN_PATH" ]]; then
  echo "Missing built binary: $BIN_PATH"
  exit 1
fi

echo "Packaging app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"

cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
cp "$ICON_FILE" "$RES_DIR/AppIcon.icns"
if [[ -d "$HELP_BOOK_DIR" ]]; then
  cp -R "$HELP_BOOK_DIR" "$RES_DIR/"
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>$APP_NAME</string>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>com.x.seditor</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundleHelpBookFolder</key>
  <string>SeditorHelp.help</string>
  <key>CFBundleHelpBookName</key>
  <string>Seditor Help</string>
  <key>CFBundleDocumentTypes</key>
  <array>
    <dict>
      <key>CFBundleTypeName</key>
      <string>Text Document</string>
      <key>CFBundleTypeRole</key>
      <string>Editor</string>
      <key>LSHandlerRank</key>
      <string>Default</string>
      <key>LSItemContentTypes</key>
      <array>
        <string>public.plain-text</string>
        <string>public.text</string>
      </array>
      <key>CFBundleTypeExtensions</key>
      <array>
        <string>txt</string>
        <string>text</string>
        <string>md</string>
        <string>log</string>
      </array>
    </dict>
  </array>
</dict>
</plist>
PLIST

cat > "$CONTENTS_DIR/PkgInfo" <<PKG
APPL????
PKG

echo "Done: $APP_DIR"
