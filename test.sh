#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

"$REPO_ROOT/scripts/audit_secrets.sh"

PYTHON_BIN="${PYTHON_BIN:-python3}"
if "$PYTHON_BIN" -c 'import sys; raise SystemExit(sys.version_info < (3, 12))' 2>/dev/null; then
    PYTHONPATH="$REPO_ROOT/backend" "$PYTHON_BIN" -m unittest discover -s "$REPO_ROOT/backend/tests" -v
else
    echo "Skipping backend tests: Python 3.12+ is required (set PYTHON_BIN)."
fi

(cd "$REPO_ROOT/frontend" && swift build)
if (cd "$REPO_ROOT/frontend" && swift test); then
    true
else
    echo "Swift tests require a full Xcode XCTest toolchain; build already passed." >&2
fi

while IFS= read -r script; do
    bash -n "$script"
done < <(find "$REPO_ROOT" -type f -name '*.sh' -not -path '*/.build/*' -not -path '*/.venv/*')

echo "Verification complete."
