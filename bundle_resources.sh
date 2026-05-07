#!/bin/bash
# bundle_resources.sh
# Copy the frozen backend binary and pre-baked HuggingFace model cache from
# frontend/RepoWhisper/Resources/ into a built .app's Contents/Resources/.
#
# We do this as a post-build step instead of as an Xcode "Copy Bundle
# Resources" build phase because adding folder references to project.pbxproj
# without Xcode is error-prone. Once your DMG flow is stable you can move
# this into a Run Script phase inside Xcode.
#
# Usage:
#   ./bundle_resources.sh path/to/RepoWhisper.app

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <path/to/RepoWhisper.app>"
    exit 1
fi

APP_PATH="$1"
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
SOURCE_RESOURCES="$REPO_ROOT/frontend/RepoWhisper/Resources"
DEST_RESOURCES="$APP_PATH/Contents/Resources"

if [[ ! -d "$APP_PATH" ]]; then
    echo "❌ App bundle not found: $APP_PATH"
    exit 1
fi

if [[ ! -d "$DEST_RESOURCES" ]]; then
    echo "❌ $APP_PATH does not look like a built .app (no Contents/Resources)."
    exit 1
fi

# ---- Backend binary ----
BINARY="$SOURCE_RESOURCES/repowhisper-backend-arm64"
if [[ ! -x "$BINARY" ]]; then
    echo "❌ Backend binary missing at $BINARY"
    echo "   Run ./build_binaries.sh first."
    exit 1
fi
cp "$BINARY" "$DEST_RESOURCES/"
chmod +x "$DEST_RESOURCES/repowhisper-backend-arm64"
BIN_SIZE=$(du -h "$DEST_RESOURCES/repowhisper-backend-arm64" | awk '{print $1}')
echo "✅ Backend binary copied ($BIN_SIZE)"

# ---- Bundled models (optional) ----
if [[ -d "$SOURCE_RESOURCES/models" ]]; then
    rm -rf "$DEST_RESOURCES/models"
    cp -R "$SOURCE_RESOURCES/models" "$DEST_RESOURCES/"
    MODEL_SIZE=$(du -sh "$DEST_RESOURCES/models" | awk '{print $1}')
    echo "✅ Bundled models copied ($MODEL_SIZE)"
else
    echo "⚠️  No models/ folder found — first launch will download from HuggingFace."
    echo "   To bundle, run: ./prebake_models.sh"
fi

# Re-sign the app so the embedded binary is included in the signature.
# In dev (Debug) builds this is a no-op ad-hoc sign; in Release you'll want
# to pass --sign with your Developer ID identity instead.
SIGN_IDENTITY="${CODESIGN_IDENTITY:-}"
if [[ -n "$SIGN_IDENTITY" ]]; then
    echo "🔏 Re-signing with: $SIGN_IDENTITY"
    codesign --force --deep --options runtime \
        --entitlements "$REPO_ROOT/frontend/RepoWhisper/RepoWhisper.entitlements" \
        --sign "$SIGN_IDENTITY" "$APP_PATH"
else
    echo "🔏 Re-signing ad-hoc (override with CODESIGN_IDENTITY env var for Release)"
    codesign --force --deep --sign - "$APP_PATH"
fi

echo "✅ Done."
echo ""
echo "Next: ./create_dmg.sh $APP_PATH"
