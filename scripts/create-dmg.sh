#!/bin/bash
# Creates a DMG with drag-to-Applications layout for PattiSpecialButton
# Uses create-dmg (brew install create-dmg) for reliable Finder layout.
#
# Usage: ./create-dmg.sh [path-to-app]
# If no path given, looks for the app in the default build locations.

set -euo pipefail

APP_NAME="PattiSpecialButton"
APP_TARGET="pattiSpecialButton"
VOL_NAME="${APP_NAME}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BG_IMAGE="$SCRIPT_DIR/dmg-background.png"
STAGING_DIR="$SCRIPT_DIR/.dmg-staging"

# Find the .app
if [ $# -ge 1 ]; then
    APP_PATH="$1"
else
    # Check project-local build/ directory first (from xcodebuild)
    APP_PATH="$(find "$PROJECT_DIR/build" -name "${APP_TARGET}.app" -path "*/Release/*" -not -path "*/Intermediates*" 2>/dev/null | head -1)"

    # Then check Xcode archives (newest first)
    if [ -z "$APP_PATH" ]; then
        APP_PATH="$(find ~/Library/Developer/Xcode/Archives -name "${APP_TARGET}.app" -path "*/Applications/*" 2>/dev/null | sort -r | head -1)"
    fi

    # Then check DerivedData (exclude archive intermediates)
    if [ -z "$APP_PATH" ]; then
        APP_PATH="$(find ~/Library/Developer/Xcode/DerivedData -name "${APP_TARGET}.app" -path "*/Release/*" -not -path "*/Intermediates*" 2>/dev/null | head -1)"
    fi

    if [ -z "$APP_PATH" ]; then
        echo "Error: Could not find ${APP_TARGET}.app."
        echo "Build in Release mode first, or pass the .app path as an argument."
        exit 1
    fi
fi

if [ ! -d "$APP_PATH" ]; then
    echo "Error: $APP_PATH does not exist or is not a directory."
    exit 1
fi

echo "Using app: $APP_PATH"

# Read version from the built app's Info.plist
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" 2>/dev/null || echo "0.0")
DMG_NAME="${APP_NAME}-v${VERSION}"
DMG_OUTPUT="$PROJECT_DIR/${DMG_NAME}.dmg"

echo "Version: $VERSION"

# Clean up previous artifacts
rm -rf "$STAGING_DIR"
rm -f "$DMG_OUTPUT"

# Stage the app
mkdir -p "$STAGING_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/${APP_NAME}.app"

# Create DMG with create-dmg
echo "Creating DMG..."
create-dmg \
    --volname "$VOL_NAME" \
    --background "$BG_IMAGE" \
    --window-size 500 650 \
    --icon-size 100 \
    --icon "${APP_NAME}.app" 250 160 \
    --app-drop-link 250 450 \
    --hide-extension "${APP_NAME}.app" \
    --no-internet-enable \
    "$DMG_OUTPUT" \
    "$STAGING_DIR"

# Clean up staging
rm -rf "$STAGING_DIR"

echo ""
echo "DMG created: $DMG_OUTPUT"
echo "Size: $(du -h "$DMG_OUTPUT" | cut -f1)"
