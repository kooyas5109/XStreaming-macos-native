#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/arm64-apple-macosx/debug"
APP_NAME="XStreamingMacApp"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
EXECUTABLE="$BUILD_DIR/$APP_NAME"
AUTH_MODE="${XSTREAMING_AUTH_MODE:-live}"

swift build --package-path "$ROOT_DIR" --product "$APP_NAME"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>zh_CN</string>
    <key>CFBundleExecutable</key>
    <string>XStreamingMacApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.kooyas5109.XStreamingMacNative.dev</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>XStreamingMacApp</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSEnvironment</key>
    <dict>
        <key>XSTREAMING_AUTH_MODE</key>
        <string>__AUTH_MODE__</string>
    </dict>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

python3 - <<PY
from pathlib import Path
path = Path("$CONTENTS_DIR/Info.plist")
path.write_text(path.read_text().replace("__AUTH_MODE__", "$AUTH_MODE"))
PY

cp "$EXECUTABLE" "$MACOS_DIR/$APP_NAME"

if [[ -d "$BUILD_DIR/XStreamingMacApp_XStreamingMacApp.resources" ]]; then
    rsync -a --delete "$BUILD_DIR/XStreamingMacApp_XStreamingMacApp.resources/" "$RESOURCES_DIR/"
fi

open "$APP_BUNDLE"
