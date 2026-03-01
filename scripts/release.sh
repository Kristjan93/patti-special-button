#!/bin/bash
# ──────────────────────────────────────────────────────────────────────
# Release script for PattiSpecialButton
#
# Does everything needed to produce a signed, distributable DMG:
#   1. Builds a Universal Binary (arm64 + x86_64) in Release mode
#   2. Packages it into a DMG with drag-to-Applications layout
#   3. Signs the DMG with the Sparkle EdDSA key
#   4. Generates the appcast.xml <item> block
#
# Usage:
#   ./scripts/release.sh              # full release
#   ./scripts/release.sh --skip-build # repackage existing Release build
#
# Prerequisites:
#   brew install create-dmg
#   Sparkle signing key in Keychain (account: patti-special-button)
# ──────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_TARGET="pattiSpecialButton"
APP_NAME="PattiSpecialButton"
SPARKLE_ACCOUNT="patti-special-button"
BUILD_DIR="$PROJECT_DIR/build"
SKIP_BUILD=false

for arg in "$@"; do
    case "$arg" in
        --skip-build) SKIP_BUILD=true ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

# ── Step 1: Build ────────────────────────────────────────────────────

if [ "$SKIP_BUILD" = false ]; then
    echo "═══ Step 1: Building Universal Binary (Release) ═══"
    echo ""
    xcodebuild \
        -scheme "$APP_TARGET" \
        -configuration Release \
        -derivedDataPath "$BUILD_DIR" \
        ARCHS="arm64 x86_64" \
        ONLY_ACTIVE_ARCH=NO \
        2>&1 | tail -5

    echo ""
fi

# Find the built app
APP_PATH="$(find "$BUILD_DIR" -name "${APP_TARGET}.app" -path "*/Release/*" -not -path "*/Intermediates*" 2>/dev/null | head -1)"

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "Error: Could not find ${APP_TARGET}.app in $BUILD_DIR"
    echo "Build in Release mode first, or remove --skip-build."
    exit 1
fi

# Read version from the built app
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP_PATH/Contents/Info.plist")
DMG_FILENAME="${APP_NAME}-v${VERSION}.dmg"
DMG_PATH="$PROJECT_DIR/$DMG_FILENAME"

echo "═══ App: $APP_PATH ═══"
echo "    Version: $VERSION (build $BUILD)"
echo ""

# Verify Sparkle keys are in the plist
if ! /usr/libexec/PlistBuddy -c "Print SUPublicEDKey" "$APP_PATH/Contents/Info.plist" >/dev/null 2>&1; then
    echo "Error: SUPublicEDKey missing from built Info.plist!"
    echo "Check that pattiSpecialButton/Info.plist has the Sparkle keys."
    exit 1
fi

# ── Step 2: Create DMG ──────────────────────────────────────────────

echo "═══ Step 2: Creating DMG ═══"
echo ""

"$SCRIPT_DIR/create-dmg.sh" "$APP_PATH"

if [ ! -f "$DMG_PATH" ]; then
    echo "Error: Expected DMG at $DMG_PATH but it doesn't exist."
    exit 1
fi

echo ""

# ── Step 3: Sign DMG ────────────────────────────────────────────────

echo "═══ Step 3: Signing DMG with EdDSA key ═══"
echo ""

# Find sign_update in DerivedData (from Sparkle SPM package)
SIGN_UPDATE="$(find ~/Library/Developer/Xcode/DerivedData/"${APP_TARGET}"-*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update 2>/dev/null | head -1)"

if [ -z "$SIGN_UPDATE" ]; then
    # Also check our own build directory
    SIGN_UPDATE="$(find "$BUILD_DIR/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update" 2>/dev/null | head -1)"
fi

if [ -z "$SIGN_UPDATE" ] || [ ! -x "$SIGN_UPDATE" ]; then
    echo "Error: Could not find Sparkle's sign_update tool."
    echo "Build the project in Xcode first so the Sparkle package is resolved."
    exit 1
fi

# sign_update outputs: sparkle:edSignature="..." length="..."
SIGN_OUTPUT=$("$SIGN_UPDATE" "$DMG_PATH" --account "$SPARKLE_ACCOUNT" 2>&1)
echo "$SIGN_OUTPUT"
echo ""

# Parse signature and length from the output
ED_SIGNATURE=$(echo "$SIGN_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)
FILE_LENGTH=$(echo "$SIGN_OUTPUT" | grep -o 'length="[^"]*"' | cut -d'"' -f2)

if [ -z "$ED_SIGNATURE" ]; then
    echo "Error: Could not parse EdDSA signature from sign_update output."
    echo "Raw output: $SIGN_OUTPUT"
    exit 1
fi

# ── Step 4: Generate appcast item ────────────────────────────────────

echo "═══ Step 4: Appcast entry ═══"
echo ""

PUB_DATE=$(date -R)

# The GitHub Releases URL where you'll upload the DMG
DOWNLOAD_URL="https://github.com/Kristjan93/patti-special-button/releases/download/v${VERSION}/${DMG_FILENAME}"

APPCAST_ITEM="    <item>
      <title>Version ${VERSION}</title>
      <pubDate>${PUB_DATE}</pubDate>
      <sparkle:version>${BUILD}</sparkle:version>
      <sparkle:shortVersionString>${VERSION}</sparkle:shortVersionString>
      <enclosure
        url=\"${DOWNLOAD_URL}\"
        type=\"application/octet-stream\"
        sparkle:edSignature=\"${ED_SIGNATURE}\"
        length=\"${FILE_LENGTH}\"
      />
    </item>"

echo "Add this inside <channel> in appcast.xml:"
echo ""
echo "$APPCAST_ITEM"
echo ""

# ── Step 5: Update appcast.xml automatically ─────────────────────────

APPCAST_FILE="$PROJECT_DIR/appcast.xml"

if [ -f "$APPCAST_FILE" ]; then
    # Insert the item before </channel>
    ESCAPED_ITEM=$(echo "$APPCAST_ITEM" | sed 's/\\/\\\\/g; s/&/\\&/g')
    sed -i '' "s|  </channel>|${ESCAPED_ITEM}\n  </channel>|" "$APPCAST_FILE"
    echo "Updated appcast.xml with new entry."
else
    echo "Warning: appcast.xml not found at $APPCAST_FILE"
    echo "Create it manually with the item block above."
fi

# ── Summary ──────────────────────────────────────────────────────────

echo ""
echo "═══════════════════════════════════════════════════"
echo "  Release v${VERSION} (build ${BUILD}) ready!"
echo "═══════════════════════════════════════════════════"
echo ""
echo "  DMG:       $DMG_PATH"
echo "  Size:      $(du -h "$DMG_PATH" | cut -f1)"
echo "  Signature: ${ED_SIGNATURE:0:20}..."
echo "  Appcast:   Updated"
echo ""
echo "  Next steps:"
echo "    1. git add appcast.xml"
echo "    2. git commit -m \"Release v${VERSION}\""
echo "    3. git tag v${VERSION}"
echo "    4. git push origin main --tags"
echo "    5. Upload ${DMG_FILENAME} to GitHub Releases (tag v${VERSION})"
echo ""
