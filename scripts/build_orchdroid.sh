#!/usr/bin/env bash
set -e

BASE_DIR="/Volumes/LinuxFS/OrchDroid"
DIST_DIR="$BASE_DIR/dist"
ICON_PATH="$BASE_DIR/apps/OrchDroid Device.app/Contents/Resources/AppIcon.icns"

echo "=========================================================="
echo "      🛠️  Compiling OrchDroid Pro for Apple Silicon       "
echo "=========================================================="

mkdir -p "$DIST_DIR"

# 1. Build OrchDroid Manager App
echo "📦 Building OrchDroid.app (Manager)..."
APP_NAME="OrchDroid"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cat <<EOF > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>OrchDroid</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.orchdroid.manager</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>OrchDroid</string>
    <key>CFBundleDisplayName</key>
    <string>OrchDroid Pro</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

cp "$ICON_PATH" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "⚡ Compiling Swift Cocoa Mach-O binary (ARM64 Native)..."
swiftc -O -target arm64-apple-macos12.0 \
  "$BASE_DIR/host_app/main.swift" \
  -o "$APP_BUNDLE/Contents/MacOS/OrchDroid"

codesign --force --deep --sign - "$APP_BUNDLE"
echo "✅ OrchDroid.app built successfully!"

# 2. Build OrchDroid Device App
echo "📦 Building OrchDroid Device.app (Player)..."
DEVICE_BUNDLE="$DIST_DIR/OrchDroid Device.app"
rm -rf "$DEVICE_BUNDLE"
mkdir -p "$DEVICE_BUNDLE/Contents/MacOS"
mkdir -p "$DEVICE_BUNDLE/Contents/Resources"

cat <<EOF > "$DEVICE_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>OrchDroidDevice</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.orchdroid.device</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>OrchDroid Device</string>
    <key>CFBundleDisplayName</key>
    <string>OrchDroid Device</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

cp "$ICON_PATH" "$DEVICE_BUNDLE/Contents/Resources/AppIcon.icns"

swiftc -O -target arm64-apple-macos12.0 \
  "$BASE_DIR/apps/device_app.swift" \
  -o "$DEVICE_BUNDLE/Contents/MacOS/OrchDroidDevice"

codesign --force --deep --sign - "$DEVICE_BUNDLE"
echo "✅ OrchDroid Device.app built successfully!"

# 3. Build Direct Input & Aim Injection Dylib (liborchdroid_ui.dylib)
echo "📦 Building liborchdroid_ui.dylib (Low-Latency Input & Trackpad)..."
clang -O2 -dynamiclib -target arm64-apple-macos12.0 \
  -fobjc-arc \
  -framework Cocoa \
  -framework Metal \
  -framework CoreImage \
  -framework QuartzCore \
  "$BASE_DIR/engine/orchdroid_ui.m" \
  -o "$DIST_DIR/liborchdroid_ui.dylib"

codesign --force --sign - "$DIST_DIR/liborchdroid_ui.dylib"
echo "✅ liborchdroid_ui.dylib built successfully!"

echo "=========================================================="
echo "🎉 Compilation Complete! Artifacts:"
echo "• $DIST_DIR/OrchDroid.app"
echo "• $DIST_DIR/OrchDroid Device.app"
echo "• $DIST_DIR/liborchdroid_ui.dylib"
echo "=========================================================="
