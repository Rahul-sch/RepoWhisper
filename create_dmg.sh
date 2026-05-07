#!/bin/bash
# create_dmg.sh
# Package an exported, signed (and ideally notarized) RepoWhisper.app
# into a distributable .dmg using the create-dmg homebrew formula.
#
# Usage:
#   ./create_dmg.sh /path/to/RepoWhisper.app [output_dir]
#
# Requires:
#   brew install create-dmg

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <path/to/RepoWhisper.app> [output_dir]"
    echo "Example: $0 ~/Desktop/Export/RepoWhisper.app ./dist"
    exit 1
fi

APP_PATH="$1"
OUTPUT_DIR="${2:-$(pwd)}"

# ---- 1. Sanity checks ----

if [[ ! -d "$APP_PATH" ]]; then
    echo "❌ App bundle not found: $APP_PATH"
    exit 1
fi

if [[ ! -d "$APP_PATH/Contents/MacOS" ]]; then
    echo "❌ $APP_PATH does not look like a .app bundle (no Contents/MacOS)."
    exit 1
fi

if ! command -v create-dmg >/dev/null 2>&1; then
    echo "❌ create-dmg not installed."
    echo "   Install with:  brew install create-dmg"
    exit 1
fi

# ---- 2. Read app metadata for the volume label ----

INFO_PLIST="$APP_PATH/Contents/Info.plist"
APP_NAME=$(basename "$APP_PATH" .app)
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || echo "0.1.0")

DMG_NAME="$APP_NAME-$VERSION.dmg"
DMG_PATH="$OUTPUT_DIR/$DMG_NAME"

mkdir -p "$OUTPUT_DIR"

# Remove a stale DMG so create-dmg doesn't refuse to overwrite.
rm -f "$DMG_PATH"

echo "📦 Packaging $APP_NAME v$VERSION → $DMG_PATH"

# ---- 3. Stage the .app in a clean temp directory ----
# create-dmg packages the contents of a source folder, so we put just
# the .app in a temp dir to keep the DMG tidy.

STAGE_DIR=$(mktemp -d)
trap 'rm -rf "$STAGE_DIR"' EXIT
cp -R "$APP_PATH" "$STAGE_DIR/"

# ---- 4. Build the DMG ----
# Layout: app icon at left, /Applications shortcut at right, drag to install.
# --no-internet-enable: don't auto-mount when downloaded (security best practice).
# --skip-jenkins: don't read jenkins-specific defaults.

create-dmg \
    --volname "$APP_NAME $VERSION" \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "$APP_NAME.app" 175 190 \
    --hide-extension "$APP_NAME.app" \
    --app-drop-link 425 190 \
    --no-internet-enable \
    --skip-jenkins \
    "$DMG_PATH" \
    "$STAGE_DIR"

# ---- 5. Report + next steps ----

SIZE=$(du -h "$DMG_PATH" | awk '{print $1}')
cat <<EOF

✅ DMG created.
   Path: $DMG_PATH
   Size: $SIZE

Distribution checklist:
  1. Notarize:
       xcrun notarytool submit "$DMG_PATH" \\
         --keychain-profile "AC_PASSWORD" --wait
     (One-time setup of AC_PASSWORD profile:
      xcrun notarytool store-credentials AC_PASSWORD --apple-id <you> --team-id <TEAMID>)

  2. Staple the notarization ticket:
       xcrun stapler staple "$DMG_PATH"

  3. Verify:
       xcrun stapler validate "$DMG_PATH"
       spctl -a -vvv -t install "$DMG_PATH"

  4. Distribute the resulting .dmg.
EOF
