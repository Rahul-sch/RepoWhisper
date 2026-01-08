#!/bin/bash
# Quick test script for RepoWhisper backend

echo "🧪 Testing RepoWhisper Backend..."
echo ""

# Test health endpoint
echo "1. Testing /health endpoint..."
HEALTH=$(curl -s http://127.0.0.1:8000/health 2>&1)
if echo "$HEALTH" | grep -q "healthy"; then
    echo "   ✅ Health check passed"
    echo "$HEALTH" | python3 -m json.tool 2>/dev/null || echo "$HEALTH"
else
    echo "   ❌ Health check failed"
    echo "   Make sure backend is running: ./START_BACKEND.sh"
    exit 1
fi

echo ""
echo "2. Testing /docs endpoint..."
DOCS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/docs)
if [ "$DOCS" = "200" ]; then
    echo "   ✅ API docs available at: http://127.0.0.1:8000/docs"
else
    echo "   ⚠️  Docs endpoint returned: $DOCS"
fi

echo ""
echo "✅ Backend is running and responding!"
echo ""
echo "📖 View API docs: open http://127.0.0.1:8000/docs"
echo "🏥 Health check: curl http://127.0.0.1:8000/health"

