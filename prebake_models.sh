#!/bin/bash
# prebake_models.sh
# Pre-download the Whisper and sentence-transformers model weights into
# frontend/RepoWhisper/Resources/models/hf so the bundled .app doesn't need
# internet on first launch (~230 MB total).
#
# At runtime, BackendProcessManager points HF_HOME at this directory so
# faster-whisper and sentence-transformers find the cached weights.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
RESOURCES_DIR="$REPO_ROOT/frontend/RepoWhisper/Resources"
MODELS_DIR="$RESOURCES_DIR/models/hf"

if [[ -z "${VIRTUAL_ENV:-}" ]]; then
    echo "⚠️  No active venv. Activate backend/venv first (the same one used for build_binaries.sh)."
    read -r -p "   Continue with system Python? (y/N) " reply
    [[ ! "$reply" =~ ^[Yy]$ ]] && exit 1
fi

PYTHON="${PYTHON:-python3}"

mkdir -p "$MODELS_DIR"
echo "📥 Pre-downloading models into $MODELS_DIR ..."

# Run the loaders with HF_HOME pointed at the bundle dir.
HF_HOME="$MODELS_DIR" SENTENCE_TRANSFORMERS_HOME="$MODELS_DIR" \
"$PYTHON" - <<'PY'
import os
print(f"HF_HOME = {os.environ.get('HF_HOME')}")

# Sentence-transformers (all-MiniLM-L6-v2, ~90 MB)
from sentence_transformers import SentenceTransformer
print("→ sentence-transformers/all-MiniLM-L6-v2")
m = SentenceTransformer("all-MiniLM-L6-v2")
m.encode("warmup", show_progress_bar=False)
print("  ✅ embedding model cached")

# Faster-Whisper (Systran/faster-whisper-tiny.en, ~140 MB)
try:
    from faster_whisper import WhisperModel
    print("→ Systran/faster-whisper-tiny.en")
    w = WhisperModel("tiny.en", device="cpu", compute_type="int8")
    print("  ✅ whisper model cached")
except ImportError:
    print("  ⚠️  faster-whisper not installed — skipping (transcription will need download at runtime)")
PY

# Show what we actually downloaded.
SIZE=$(du -sh "$MODELS_DIR" 2>/dev/null | awk '{print $1}')
COUNT=$(find "$MODELS_DIR" -type f 2>/dev/null | wc -l | tr -d ' ')

cat <<EOF

✅ Models bundled.
   Path:  $MODELS_DIR
   Files: $COUNT
   Size:  $SIZE

These weights will ship inside RepoWhisper.app bundle Resources.
Make sure 'models' folder is included in Xcode's "Copy Bundle Resources"
build phase (or Xcode will copy the parent Resources/ folder reference).
EOF
