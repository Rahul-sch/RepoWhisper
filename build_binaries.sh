#!/bin/bash
# build_binaries.sh
# Freeze the RepoWhisper FastAPI backend into a single self-contained
# Apple Silicon (arm64) executable using PyInstaller, and copy the result
# into the macOS app's bundle Resources so BackendProcessManager can find it.
#
# Run this on an arm64 Mac with an active Python venv that has the backend
# requirements installed. PyInstaller will be installed if missing.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
BACKEND_DIR="$REPO_ROOT/backend"
RESOURCES_DIR="$REPO_ROOT/frontend/RepoWhisper/Resources"
BINARY_NAME="repowhisper-backend-arm64"

# ---- 1. Sanity checks ----

if [[ "$(uname -s)" != "Darwin" ]]; then
    echo "❌ This script must run on macOS (got $(uname -s))."
    exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
    echo "❌ This script must run on Apple Silicon (got $(uname -m))."
    echo "   For an Intel build, run on an Intel Mac and rename the binary"
    echo "   to repowhisper-backend-x86_64."
    exit 1
fi

if [[ -z "${VIRTUAL_ENV:-}" ]]; then
    echo "⚠️  No active Python venv detected."
    echo "   Recommended: source backend/venv/bin/activate first, otherwise"
    echo "   PyInstaller will pull from your system Python and the binary"
    echo "   will be huge / brittle."
    read -r -p "   Continue anyway? (y/N) " reply
    [[ ! "$reply" =~ ^[Yy]$ ]] && exit 1
fi

PYTHON="${PYTHON:-python3}"
echo "🐍 Using Python: $($PYTHON --version) ($(which $PYTHON))"

# ---- 2. Make sure PyInstaller is available ----

if ! "$PYTHON" -c "import PyInstaller" 2>/dev/null; then
    echo "📦 PyInstaller not found — installing..."
    "$PYTHON" -m pip install --upgrade pyinstaller
fi

# ---- 3. Make sure backend deps are installed ----

if ! "$PYTHON" -c "import fastapi, uvicorn, lancedb, sentence_transformers" 2>/dev/null; then
    echo "📦 Installing backend requirements..."
    "$PYTHON" -m pip install -r "$BACKEND_DIR/requirements.txt"
fi

# faster-whisper is "soft-required" — backend works without it but
# transcription is disabled. Bundle it if present.
if "$PYTHON" -c "import faster_whisper" 2>/dev/null; then
    FASTER_WHISPER_FLAG="--collect-all faster_whisper --hidden-import ctranslate2"
    echo "✅ faster-whisper detected — will be bundled."
else
    FASTER_WHISPER_FLAG=""
    echo "⚠️  faster-whisper NOT installed — transcription will be disabled in the bundled binary."
fi

# ---- 4. Build ----

cd "$BACKEND_DIR"

# Wipe previous build so we don't ship stale artifacts.
rm -rf build dist "${BINARY_NAME}.spec"

echo "🔨 Building $BINARY_NAME with PyInstaller..."
echo "   This takes 3–5 minutes the first time."

# Notes on the flags:
# --collect-all <pkg>: bundle all submodules + datas + binaries for these
#     ML packages (their import graph is too dynamic for PyInstaller's
#     static analysis to catch on its own).
# --copy-metadata: required so packages that introspect their own
#     installed-version metadata at runtime (sentence-transformers,
#     transformers, torch) don't crash.
# --hidden-import: explicit imports PyInstaller misses.
# --paths: ensure relative imports inside the backend module resolve.
# --noconfirm: don't prompt to overwrite dist/.
# --onefile: one self-contained executable (slower startup, simpler ship).
# --console: backend prints to stdout — keep it visible to log files.
pyinstaller \
    --noconfirm \
    --onefile \
    --console \
    --name "$BINARY_NAME" \
    --paths "$BACKEND_DIR" \
    --collect-all sentence_transformers \
    --collect-all transformers \
    --collect-all tokenizers \
    --collect-all torch \
    --collect-all huggingface_hub \
    --collect-all lancedb \
    --collect-all pyarrow \
    --copy-metadata torch \
    --copy-metadata sentence_transformers \
    --copy-metadata transformers \
    --copy-metadata regex \
    --copy-metadata tqdm \
    --copy-metadata filelock \
    --copy-metadata packaging \
    --copy-metadata numpy \
    --hidden-import onnxruntime \
    $FASTER_WHISPER_FLAG \
    main.py

# ---- 5. Verify ----

BUILT_BINARY="$BACKEND_DIR/dist/$BINARY_NAME"
if [[ ! -x "$BUILT_BINARY" ]]; then
    echo "❌ Build failed — $BUILT_BINARY does not exist or isn't executable."
    exit 1
fi

# Make sure it's an arm64 binary, not a fat universal that snuck in.
ARCH_INFO=$(file "$BUILT_BINARY")
if ! echo "$ARCH_INFO" | grep -q "arm64"; then
    echo "❌ Built binary is not arm64. file output:"
    echo "$ARCH_INFO"
    exit 1
fi

# ---- 6. Copy into the macOS app bundle's Resources ----

mkdir -p "$RESOURCES_DIR"
cp "$BUILT_BINARY" "$RESOURCES_DIR/$BINARY_NAME"
chmod +x "$RESOURCES_DIR/$BINARY_NAME"

SIZE=$(du -h "$RESOURCES_DIR/$BINARY_NAME" | awk '{print $1}')

cat <<EOF

✅ Backend binary built and staged.
   Path:   $RESOURCES_DIR/$BINARY_NAME
   Size:   $SIZE
   Arch:   arm64

Next steps:
  1. In Xcode, make sure the binary is in the RepoWhisper target's
     "Copy Bundle Resources" build phase. (Drag it in once if it's not.)
  2. Product → Archive → Distribute App → Developer ID → upload for notarization.
  3. After Xcode exports the .app, run:
        ./create_dmg.sh /path/to/RepoWhisper.app

Note: this script does NOT bundle the Whisper or sentence-transformers
model weights. They download from HuggingFace on first /warmup call.
For a fully offline DMG, pre-cache the models into Resources/models/
and set REPOWHISPER_MODELS_DIR to point there in BackendProcessManager.
EOF
