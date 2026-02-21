#!/bin/bash
# Creates a DMG with drag-to-Applications layout for PattiSpecialButton
#
# Usage: ./create-dmg.sh [path-to-app]
# If no path given, looks for the app in the default Xcode build location.

set -euo pipefail

APP_NAME="PattiSpecialButton"
DMG_NAME="${APP_NAME}-v1.0"
VOL_NAME="${APP_NAME}"
DMG_SIZE="50m"

# Find the .app
if [ $# -ge 1 ]; then
    APP_PATH="$1"
else
    APP_PATH="$(find ~/Library/Developer/Xcode/DerivedData -name "${APP_NAME}.app" -path "*/Release/*" 2>/dev/null | head -1)"
    if [ -z "$APP_PATH" ]; then
        # Fall back to pattiSpecialButton target name
        APP_PATH="$(find ~/Library/Developer/Xcode/DerivedData -name "pattiSpecialButton.app" -path "*/Release/*" 2>/dev/null | head -1)"
    fi
    if [ -z "$APP_PATH" ]; then
        echo "Error: Could not find ${APP_NAME}.app in DerivedData."
        echo "Build in Release mode first, or pass the .app path as an argument."
        exit 1
    fi
fi

if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH does not exist or is not a directory."
    exit 1
fi

echo "Using app: $APP_PATH"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
STAGING_DIR="$SCRIPT_DIR/.dmg-staging"
DMG_OUTPUT="$SCRIPT_DIR/../${DMG_NAME}.dmg"

# Clean up previous artifacts
rm -rf "$STAGING_DIR"
rm -f "$DMG_OUTPUT"

# Create staging directory
mkdir -p "$STAGING_DIR"

# Copy app and create Applications symlink
cp -R "$APP_PATH" "$STAGING_DIR/${APP_NAME}.app"
ln -s /Applications "$STAGING_DIR/Applications"

# Create DMG
echo "Creating DMG..."
hdiutil create \
    -volname "$VOL_NAME" \
    -srcfolder "$STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_OUTPUT"

# Clean up staging
rm -rf "$STAGING_DIR"

echo ""
echo "DMG created: $DMG_OUTPUT"
echo "Size: $(du -h "$DMG_OUTPUT" | cut -f1)"
