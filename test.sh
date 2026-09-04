#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$REPO_ROOT/scripts/audit_secrets.sh"
"$REPO_ROOT/scripts/test_embed_backend.sh"

PYTHON_BIN="${PYTHON_BIN:-python3}"
if "$PYTHON_BIN" -c 'import sys; raise SystemExit(sys.version_info < (3, 12))' 2>/dev/null; then
    PYTHONPATH="$REPO_ROOT/backend" "$PYTHON_BIN" -m unittest discover -s "$REPO_ROOT/backend/tests" -v
else
    echo "Skipping backend tests: Python 3.12+ is required (set PYTHON_BIN)."
fi

DEVELOPER_PATH="${DEVELOPER_DIR:-}"
if [[ -z "$DEVELOPER_PATH" && -d /Applications/Xcode.app/Contents/Developer ]]; then
    DEVELOPER_PATH=/Applications/Xcode.app/Contents/Developer
fi

if [[ -n "$DEVELOPER_PATH" ]]; then
    (cd "$REPO_ROOT/frontend" && DEVELOPER_DIR="$DEVELOPER_PATH" swift test)
    DEVELOPER_DIR="$DEVELOPER_PATH" xcodebuild \
        -project "$REPO_ROOT/frontend/RepoWhisper.xcodeproj" \
        -scheme RepoWhisper \
        -configuration Debug \
        -derivedDataPath "$REPO_ROOT/.build/xcode" \
        CODE_SIGNING_ALLOWED=NO \
        SWIFT_TREAT_WARNINGS_AS_ERRORS=YES \
        build
else
    (cd "$REPO_ROOT/frontend" && swift build)
    echo "Skipping XCTest and Xcode target checks: full Xcode is not installed."
fi

while IFS= read -r script; do
    bash -n "$script"
done < <(find "$REPO_ROOT" -type f -name '*.sh' -not -path '*/.build/*' -not -path '*/.venv/*')

echo "Verification complete."
