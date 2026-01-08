#!/bin/bash
# Quick script to start the RepoWhisper backend

cd "$(dirname "$0")/backend"

# Kill any existing process on port 8000
echo "🔍 Checking for existing backend..."
if lsof -ti:8000 > /dev/null 2>&1; then
    echo "⚠️  Port 8000 is in use. Killing existing process..."
    lsof -ti:8000 | xargs kill -9 2>/dev/null
    sleep 1
fi

# Activate virtual environment
source venv/bin/activate

# Start the server
echo "🚀 Starting RepoWhisper backend..."
echo "📍 Server will run at: http://127.0.0.1:8000"
echo "📖 API docs at: http://127.0.0.1:8000/docs"
echo "🏥 Health check: http://127.0.0.1:8000/health"
echo ""
echo "Press CTRL+C to stop"
echo ""

python main.py

