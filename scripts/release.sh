#!/bin/bash
# ──────────────────────────────────────────────────────────────────────
# Release script for PattiSpecialButton
#
# How to release:
#   1. Commit your code changes
#   2. In Xcode: target → General → Identity → bump Version and Build
#   3. ./scripts/release.sh
#   That's it. The script builds, signs, pushes, and uploads.
#
# What it does:
#   1. Preflight checks (tools, signing key, endpoints)
#   2. Builds a Universal Binary (arm64 + x86_64) in Release mode
#   3. Packages it into a DMG with drag-to-Applications layout
#   4. Signs the DMG with the Sparkle EdDSA key
#   5. Updates appcast.xml with the signed entry
#   6. Commits and tags the release
#   7. Pushes to GitHub and creates a GitHub Release with the DMG
#
# Prerequisites:
#   brew install create-dmg gh
#   Sparkle signing key in Keychain (account: patti-special-button)
# ──────────────────────────────────────────────────────────────────────

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
APP_TARGET="pattiSpecialButton"
APP_NAME="PattiSpecialButton"
SPARKLE_ACCOUNT="patti-special-button"
FEED_URL="https://raw.githubusercontent.com/Kristjan93/patti-special-button/main/appcast.xml"
REPO_API="https://api.github.com/repos/Kristjan93/patti-special-button"
BUILD_DIR="$PROJECT_DIR/build"
SKIP_BUILD=false

for arg in "$@"; do
    case "$arg" in
        --skip-build) SKIP_BUILD=true ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

# ── Preflight checks ────────────────────────────────────────────────

echo "═══ Preflight checks ═══"
echo ""

PREFLIGHT_OK=true

if ! command -v xcodebuild &>/dev/null; then
    echo "  FAIL  xcodebuild not found. Install Xcode from the App Store."
    PREFLIGHT_OK=false
else
    echo "  OK    xcodebuild"
fi

if ! command -v create-dmg &>/dev/null; then
    echo "  FAIL  create-dmg not found. Install with: brew install create-dmg"
    PREFLIGHT_OK=false
else
    echo "  OK    create-dmg"
fi

if ! command -v gh &>/dev/null; then
    echo "  FAIL  gh not found. Install with: brew install gh"
    PREFLIGHT_OK=false
else
    echo "  OK    gh"
fi

if security find-generic-password -a "$SPARKLE_ACCOUNT" -s "https://sparkle-project.org" &>/dev/null 2>&1; then
    echo "  OK    Sparkle signing key (Keychain account: $SPARKLE_ACCOUNT)"
else
    echo "  FAIL  Sparkle signing key not found in Keychain."
    echo "        Generate one with:"
    echo "        find ~/Library/Developer/Xcode/DerivedData/${APP_TARGET}-*/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -maxdepth 0 | head -1 | xargs -I{} {} --account $SPARKLE_ACCOUNT"
    PREFLIGHT_OK=false
fi

HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$FEED_URL" 2>/dev/null || echo "000")
if [ "$HTTP_STATUS" = "200" ]; then
    echo "  OK    Appcast feed reachable"
else
    echo "  FAIL  Appcast feed not reachable (HTTP $HTTP_STATUS)."
    echo "        URL: $FEED_URL"
    echo "        Fix: push appcast.xml to main branch first."
    PREFLIGHT_OK=false
fi

REPO_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$REPO_API" 2>/dev/null || echo "000")
if [ "$REPO_STATUS" = "200" ]; then
    echo "  OK    GitHub repo accessible"
else
    echo "  FAIL  GitHub repo not accessible (HTTP $REPO_STATUS)."
    echo "        URL: $REPO_API"
    PREFLIGHT_OK=false
fi

if [ -f "$PROJECT_DIR/appcast.xml" ]; then
    echo "  OK    Local appcast.xml exists"
else
    echo "  FAIL  appcast.xml not found in project root."
    PREFLIGHT_OK=false
fi

echo ""

if [ "$PREFLIGHT_OK" = false ]; then
    echo "Preflight failed. Fix the issues above and try again."
    exit 1
fi

# ── Step 1: Build ────────────────────────────────────────────────────

if [ "$SKIP_BUILD" = false ]; then
    echo "═══ Step 1: Building Universal Binary (Release) ═══"
    echo ""
    rm -rf "$BUILD_DIR"
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

# Read version and build number from the built app
VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist")
BUILD=$(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "$APP_PATH/Contents/Info.plist")
DMG_FILENAME="${APP_NAME}-v${VERSION}.dmg"
DMG_PATH="$PROJECT_DIR/$DMG_FILENAME"

echo "  Version: $VERSION (build $BUILD)"
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

SIGN_UPDATE="$(find ~/Library/Developer/Xcode/DerivedData/"${APP_TARGET}"-*/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update 2>/dev/null | head -1)"

if [ -z "$SIGN_UPDATE" ]; then
    SIGN_UPDATE="$(find "$BUILD_DIR/SourcePackages/artifacts/sparkle/Sparkle/bin/sign_update" 2>/dev/null | head -1)"
fi

if [ -z "$SIGN_UPDATE" ] || [ ! -x "$SIGN_UPDATE" ]; then
    echo "Error: Could not find Sparkle's sign_update tool."
    echo "Build the project in Xcode first so the Sparkle package is resolved."
    exit 1
fi

SIGN_OUTPUT=$("$SIGN_UPDATE" "$DMG_PATH" --account "$SPARKLE_ACCOUNT" 2>&1)
echo "$SIGN_OUTPUT"
echo ""

ED_SIGNATURE=$(echo "$SIGN_OUTPUT" | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)
FILE_LENGTH=$(echo "$SIGN_OUTPUT" | grep -o 'length="[^"]*"' | cut -d'"' -f2)

if [ -z "$ED_SIGNATURE" ]; then
    echo "Error: Could not parse EdDSA signature from sign_update output."
    echo "Raw output: $SIGN_OUTPUT"
    exit 1
fi

# ── Step 4: Update appcast.xml ────────────────────────────────────

echo "═══ Step 4: Updating appcast.xml ═══"
echo ""

PUB_DATE=$(date -R)
DOWNLOAD_URL="https://github.com/Kristjan93/patti-special-button/releases/download/v${VERSION}/PattiSpecialButton.dmg"

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

APPCAST_FILE="$PROJECT_DIR/appcast.xml"

if [ -f "$APPCAST_FILE" ]; then
    python3 -c "
import sys
appcast = open(sys.argv[1]).read()
item = sys.argv[2]
appcast = appcast.replace('  </channel>', item + '\n  </channel>')
open(sys.argv[1], 'w').write(appcast)
" "$APPCAST_FILE" "$APPCAST_ITEM"
    echo "Updated appcast.xml."
else
    echo "Warning: appcast.xml not found at $APPCAST_FILE"
fi

# ── Step 5: Git commit and tag ─────────────────────────────────────

echo ""
echo "═══ Step 5: Committing and tagging ═══"
echo ""

cd "$PROJECT_DIR"
git add appcast.xml
git commit -m "Release v${VERSION}"
git tag "v${VERSION}"

echo ""

# ── Step 6: Push and create GitHub Release ────────────────────────

echo ""
echo "═══ Step 6: Pushing and uploading to GitHub ═══"
echo ""

git push origin main --tags
cp "$DMG_PATH" "$PROJECT_DIR/PattiSpecialButton.dmg"
gh release create "v${VERSION}" "$DMG_PATH" "$PROJECT_DIR/PattiSpecialButton.dmg" \
    --title "v${VERSION}" \
    --notes "Version ${VERSION}"
rm "$PROJECT_DIR/PattiSpecialButton.dmg"

echo ""

# ── Done ──────────────────────────────────────────────────────────

echo "═══════════════════════════════════════════════════"
echo "  Release v${VERSION} is live!"
echo "═══════════════════════════════════════════════════"
echo ""
