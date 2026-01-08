#!/bin/bash
# Quick script to start the RepoWhisper backend

cd "$(dirname "$0")/backend"

# Activate virtual environment
source venv/bin/activate

# Start the server
echo "🚀 Starting RepoWhisper backend..."
echo "📍 Server will run at: http://127.0.0.1:8000"
echo "📖 API docs at: http://127.0.0.1:8000/docs"
echo ""
echo "Press CTRL+C to stop"
echo ""

python main.py

