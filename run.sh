#!/bin/bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "--help" ]]; then
    echo "Usage: ./run.sh [--clean]"
    exit 0
fi
if [[ "${1:-}" == "--clean" ]]; then
    xcodebuild -project "$REPO_ROOT/frontend/RepoWhisper.xcodeproj" -scheme RepoWhisper clean
fi

xcodebuild \
    -project "$REPO_ROOT/frontend/RepoWhisper.xcodeproj" \
    -scheme RepoWhisper \
    -configuration Debug \
    -derivedDataPath "$REPO_ROOT/.build/xcode" \
    build

APP_PATH="$REPO_ROOT/.build/xcode/Build/Products/Debug/RepoWhisper.app"
open "$APP_PATH"
