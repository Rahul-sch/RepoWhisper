#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

tracked_text=$(git grep -Il '' -- . ':!scripts/audit_secrets.sh' || true)
if [[ -z "$tracked_text" ]]; then
    echo "No tracked text files found."
    exit 0
fi

patterns=(
    'gsk_[A-Za-z0-9]{20,}'
    'sk-[A-Za-z0-9]{20,}'
    'eyJ[A-Za-z0-9_-]{40,}\.[A-Za-z0-9_-]{20,}'
    '-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----'
)

failed=0
for pattern in "${patterns[@]}"; do
    if printf '%s\n' "$tracked_text" | xargs grep -nE -- "$pattern"; then
        failed=1
    fi
done

if git ls-files | grep -E '(^|/)\.env($|\.)' | grep -vE '\.(example|template)$'; then
    echo "Tracked environment file detected."
    failed=1
fi

if [[ "$failed" -ne 0 ]]; then
    echo "Secret audit failed."
    exit 1
fi
echo "Secret audit passed."
