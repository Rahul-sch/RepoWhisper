#!/bin/bash
# Smoke-test the RepoWhisper backend over its Unix Domain Socket.
# The backend is spawned by the macOS app; this just verifies it's healthy.

set -euo pipefail

SUPPORT_DIR="$HOME/Library/Application Support/RepoWhisper"
SOCKET="$SUPPORT_DIR/backend.sock"
TOKEN_FILE="$SUPPORT_DIR/auth_token.txt"

echo "🧪 Testing RepoWhisper Backend..."
echo "   Socket: $SOCKET"
echo ""

if [[ ! -S "$SOCKET" ]]; then
    echo "❌ Socket not found. Make sure RepoWhisper.app is running and"
    echo "   you've approved at least one repository folder."
    exit 1
fi

if [[ ! -f "$TOKEN_FILE" ]]; then
    echo "❌ Auth token file not found at $TOKEN_FILE"
    echo "   The app generates this on first launch."
    exit 1
fi

TOKEN=$(<"$TOKEN_FILE")

echo "1. Testing /health endpoint..."
HEALTH=$(curl --silent --unix-socket "$SOCKET" \
    -H "X-Auth-Token: $TOKEN" \
    http://localhost/health)

if echo "$HEALTH" | grep -q "healthy"; then
    echo "   ✅ Health check passed"
    echo "$HEALTH" | python3 -m json.tool 2>/dev/null || echo "$HEALTH"
else
    echo "   ❌ Health check failed"
    echo "$HEALTH"
    exit 1
fi

echo ""
echo "✅ Backend is running and responding."
