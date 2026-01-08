# Quick Start - Run RepoWhisper in 5 Minutes ⚡

## Step 1: Backend Setup (2 minutes)

```bash
# Navigate to backend
cd backend

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies (this takes ~2-3 minutes)
pip install -r requirements.txt

# Create .env file (minimal - only required vars)
cp .env.minimal .env

# OR create manually with just Supabase (required):
cat > .env << 'EOF'
SUPABASE_URL=https://kjpxpppaeydireznlzwe.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtqcHhwcHBhZXlkaXJlem5sendlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc5MDIwNTIsImV4cCI6MjA4MzQ3ODA1Mn0.YAHTxLc8ThKtbqOtvKU2yda_eZv2q91-gUHnMX-laVc
SUPABASE_JWT_SECRET=e77ca237-27bf-4863-924f-22a13d135d40

# Optional: Add Groq API key for Boss Mode AI
# GROQ_API_KEY=your-groq-key-here
EOF

# Start the backend server
python main.py
```

**Keep this terminal open!** Backend should start at `http://127.0.0.1:8000`

## Step 2: Test Backend (30 seconds)

Open a **new terminal** and test:

```bash
# Health check
curl http://127.0.0.1:8000/health

# Should return: {"status":"healthy",...}
```

## Step 3: Frontend Setup (2 minutes)

### Option A: Xcode (Recommended for Testing)

1. **Open Xcode** (must be installed)
2. **File > New > Project**
3. Choose **macOS > App**
4. Product Name: `RepoWhisper`
5. Interface: **SwiftUI**
6. Language: **Swift**
7. Save location: **`/Users/rahulbainsla/Desktop/RepoWhisper/frontend/`**
8. Click **Create**

9. **Replace default files:**
   - Delete the default `ContentView.swift` and `RepoWhisperApp.swift` (if exists)
   - Drag all files from `frontend/RepoWhisper/` folder into Xcode project
   - Make sure "Copy items if needed" is checked

10. **Add Supabase SDK:**
    - File > Add Package Dependencies
    - URL: `https://github.com/supabase/supabase-swift`
    - Version: `2.0.0` or latest
    - Add to target: `RepoWhisper`

11. **Configure Info.plist:**
    - Select project > Target > Info tab
    - Add these keys:
      - `Privacy - Microphone Usage Description`: `RepoWhisper needs microphone access to transcribe your voice commands for code search.`
      - `Privacy - Screen Recording Usage Description`: `RepoWhisper needs screen recording access to capture system audio and screenshots for Boss Mode meeting intelligence.`
      - `Privacy - Accessibility Usage Description`: `RepoWhisper needs accessibility access to identify the active window for context-aware screenshots.`

12. **Build and Run:**
    - Press `⌘R` or Product > Run
    - Grant permissions when prompted

### Option B: Swift Package Manager (Faster, but no UI)

```bash
cd frontend
swift build
swift run RepoWhisper
```

## Step 4: First Test (1 minute)

1. **Launch the app** (menu bar icon appears)
2. **Click the menu bar icon**
3. **Sign up/Login:**
   - Create account with email/password
   - Or use GitHub OAuth
4. **Select a repository:**
   - Click "Browse" next to Repository field
   - Select any code repository folder
5. **Start Indexing:**
   - Choose mode (Guided is good for testing)
   - Click "Start Indexing"
   - Wait for "Successfully indexed X files" message
6. **Test Voice Search:**
   - Click "Start Listening" or press `⌘⇧R`
   - Say: "user authentication function"
   - See results appear!

## Step 5: Test Boss Mode (Optional)

1. **Enable Boss Mode toggle**
2. **Grant screen recording permission** (System Settings)
3. **Start listening**
4. **Screenshots capture automatically** (every 5s)
5. **Talking points appear** based on transcript + screenshot + code

## Troubleshooting

### Backend won't start
```bash
# Check if port 8000 is in use
lsof -i :8000

# Kill if needed
kill -9 <PID>
```

### "Module not found" in Swift
- Make sure Supabase package is added
- Clean build folder: `⌘⇧K`
- Rebuild: `⌘B`

### App can't connect to backend
- Verify backend is running: `curl http://127.0.0.1:8000/health`
- Check `SupabaseConfig.swift` has correct backend URL

### Microphone not working
- System Settings > Privacy & Security > Microphone
- Enable for RepoWhisper

### No search results
- Make sure repository is indexed first
- Check backend logs for errors
- Verify files match your indexing mode

## Quick Test Script

Save this as `test.sh` and run:

```bash
#!/bin/bash
echo "🚀 Testing RepoWhisper..."

# Test backend
echo "Testing backend..."
curl -s http://127.0.0.1:8000/health | grep -q "healthy" && echo "✅ Backend is running" || echo "❌ Backend not responding"

# Check if app is running
pgrep -f RepoWhisper > /dev/null && echo "✅ App is running" || echo "❌ App not running"

echo "Done!"
```

Make it executable: `chmod +x test.sh`

---

**That's it! You should be up and running in ~5 minutes.** 🎉

