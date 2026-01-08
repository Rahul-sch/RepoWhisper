#!/bin/bash
echo "🚀 Testing RepoWhisper..."

# Test backend
echo "Testing backend..."
if curl -s http://127.0.0.1:8000/health | grep -q "healthy"; then
    echo "✅ Backend is running"
else
    echo "❌ Backend not responding - make sure it's running on port 8000"
fi

# Check if app is running
if pgrep -f RepoWhisper > /dev/null; then
    echo "✅ App is running"
else
    echo "⚠️  App not running - launch it from Xcode"
fi

echo "Done!"

