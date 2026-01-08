# RepoWhisper Setup Guide

## Prerequisites

- Python 3.12+
- macOS 13.0+ (for SwiftUI app)
- Xcode 15+ (for building the app)
- Supabase account and project

## Backend Setup

1. **Navigate to backend directory**:
   ```bash
   cd backend
   ```

2. **Create virtual environment**:
   ```bash
   python3 -m venv venv
   source venv/bin/activate  # On macOS/Linux
   ```

3. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Configure environment**:
   - Copy `ENV_SETUP.md` instructions
   - Create `.env` file with your Supabase credentials
   - See `backend/ENV_SETUP.md` for details

5. **Run the backend**:
   ```bash
   python main.py
   ```
   
   Backend will start at `http://127.0.0.1:8000`

## Frontend Setup

### Option 1: Xcode Project (Recommended)

1. **Open Xcode** and create new macOS App project
2. **Follow instructions** in `frontend/XCODE_SETUP.md`
3. **Add Supabase Swift SDK** via Swift Package Manager
4. **Build and run** the app

### Option 2: Swift Package Manager

1. **Navigate to frontend directory**:
   ```bash
   cd frontend
   ```

2. **Build with SPM**:
   ```bash
   swift build
   ```

3. **Run the app**:
   ```bash
   swift run RepoWhisper
   ```

## First Run

1. **Start the backend** (see Backend Setup above)
2. **Launch the Swift app**
3. **Sign in** with Supabase (email/password or OAuth)
4. **Select a repository** to index
5. **Choose indexing mode**:
   - **Manual**: Select specific files
   - **Guided**: Use file patterns (e.g., `*.py, *.swift`)
   - **Full**: Index entire repository
6. **Click "Start Listening"** or press `⌘⇧R`
7. **Speak your search query** and see results!

## Troubleshooting

### Backend won't start
- Check that port 8000 is not in use
- Verify `.env` file exists and has correct values
- Check Supabase credentials are valid

### App can't connect to backend
- Ensure backend is running on `http://127.0.0.1:8000`
- Check firewall settings
- Verify `SUPABASE_URL` in `SupabaseConfig.swift` matches your project

### Microphone not working
- Grant microphone permission in System Settings > Privacy & Security
- Check `Info.plist` has microphone usage description

### No search results
- Ensure repository is indexed first
- Check that files match your indexing mode criteria
- Verify vector store was created (check `.repowhisper/{user_id}/` directory)

## Development

### Backend API Endpoints

- `GET /health` - Health check
- `POST /index` - Index a repository (requires auth)
- `POST /search` - Search code (requires auth)
- `POST /transcribe` - Transcribe audio (optional auth)
- `GET /repos` - List user's repositories (requires auth)
- `DELETE /repos/{repo_id}` - Delete repository (requires auth)

### Rate Limits

- Index: 10 requests/minute
- Search: 60 requests/minute
- Transcribe: 120 requests/minute
- Health: 100 requests/minute

## Production Deployment

See `PRODUCTION_CHECKLIST.md` for deployment requirements.

