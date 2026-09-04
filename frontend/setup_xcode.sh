#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v xcodebuild >/dev/null 2>&1; then
    echo "Xcode is required. Install it and select it with xcode-select."
    exit 1
fi
if ! command -v xcodegen >/dev/null 2>&1; then
    echo "XcodeGen is required. Install it with: brew install xcodegen"
    exit 1
fi

cd "$SCRIPT_DIR"
xcodegen generate --spec project.yml
echo "Generated $SCRIPT_DIR/RepoWhisper.xcodeproj"
open "$SCRIPT_DIR/RepoWhisper.xcodeproj"
