#!/bin/bash

# Configuration
APP_NAME="AuraLyrics"
BUILD_DIR=".build/release"
OUTPUT_DIR="dist"
EXECUTABLE="$BUILD_DIR/$APP_NAME"

echo "🚀 Starting Build Process for $APP_NAME..."

# 1. Clean and Build Release
echo "🛠️  Building Release..."
swift build -c release --disable-sandbox --product $APP_NAME

if [ $? -ne 0 ]; then
    echo "❌ Build Failed!"
    exit 1
fi

# 2. Prepare Output Directory
echo "📂 Preparing Output Directory: $OUTPUT_DIR"
rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# 3. Create .app Bundle Structure (Standard macOS App format)
APP_BUNDLE="$OUTPUT_DIR/$APP_NAME.app"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# 4. Copy Executable/Resources
echo "📦 Packaging..."
cp "$EXECUTABLE" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy resources if any (e.g. SpotifyScript.scpt)
# NOTE: SwiftPM bundles resources differently, checking build path
# If your resource is copied to the bundle by SwiftPM, we might need to copy it from .build/release/AuraLyrics_AuraLyrics.bundle
# For now, we assume simple copy if exists, or if embedded in binary logic.
# Our code looks for Bundle.main or dev path. In release app, Bundle.main is the .app.
# We need to make sure Resources are in Contents/Resources.

# Find the resource bundle created by SwiftPM (searching deeper for architecture-specific paths)
RESOURCE_BUNDLE=$(find .build -name "${APP_NAME}_${APP_NAME}.bundle" | grep "release" | head -n 1)
if [ -n "$RESOURCE_BUNDLE" ] && [ -d "$RESOURCE_BUNDLE" ]; then
    echo "   Found Resource Bundle: $RESOURCE_BUNDLE"
    cp -r "$RESOURCE_BUNDLE/"* "$APP_BUNDLE/Contents/Resources/"
fi

# Create Info.plist (Minimal)
cat <<EOF > "$APP_BUNDLE/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>com.berkayozcan.$APP_NAME</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.1</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon.icns</string>
    <key>NSAppleEventsUsageDescription</key>
    <string>AuraLyrics needs to control Spotify to get the current track and display lyrics.</string>
    <key>LSUIElement</key>
    <true/> <!-- Hides from Dock if true, removed if you want Dock icon -->
</dict>
</plist>
EOF

# 5. Ad-hoc Sign the App (Required for M1/M2/M3 chips)
echo "✍️  Ad-hoc Signing..."
codesign --force --deep --sign - "$APP_BUNDLE"

# 6. Zip it
echo "🤐 Zipping..."
cd "$OUTPUT_DIR"
ZIP_NAME="$APP_NAME.tar.gz"
tar -czf "$ZIP_NAME" "$APP_NAME.app"
SHA256=$(shasum -a 256 "$ZIP_NAME" | awk '{print $1}')

echo ""
echo "✅ Build Complete!"
echo "---------------------------------------------------"
echo "📁 Artifact: $OUTPUT_DIR/$ZIP_NAME"
echo "🔑 SHA256:   $SHA256"
echo "---------------------------------------------------"
echo "Use this SHA256 in your Homebrew formula."
