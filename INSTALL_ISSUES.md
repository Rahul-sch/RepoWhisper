# Installation Issues & Fixes

## faster-whisper Installation

### Problem
`faster-whisper` requires C++ build tools and `pkg-config` to compile.

### Solution

**Option 1: Install dependencies first (Recommended)**
```bash
# Install pkg-config
brew install pkg-config

# Then install faster-whisper
cd backend
source venv/bin/activate
pip install faster-whisper
```

**Option 2: Skip it (Backend works without it!)**
- The backend is already configured to run without `faster-whisper`
- Transcription will return empty text until installed
- All other features (search, indexing, Boss Mode) work fine

### Why the error happened

1. **`pip` not found**: You need to activate the virtual environment first
   ```bash
   cd backend
   source venv/bin/activate  # This activates pip
   ```

2. **`brew install faster-whisper` failed**: faster-whisper is a Python package, not a Homebrew formula
   - Use `pip install` (not `brew install`)
   - Must be in the activated virtual environment

3. **Build error**: Needs `pkg-config` for compilation
   - Install via: `brew install pkg-config`

## Quick Fix Commands

```bash
# 1. Navigate to backend
cd /Users/rahulbainsla/Desktop/RepoWhisper/backend

# 2. Activate virtual environment
source venv/bin/activate

# 3. Install pkg-config (if needed)
brew install pkg-config

# 4. Install faster-whisper
pip install faster-whisper

# 5. Test backend
python main.py
```

## Current Status

✅ **Backend runs without faster-whisper**
- Health endpoint works
- Search works
- Indexing works
- Boss Mode works
- Only transcription returns empty (until faster-whisper installed)

You can test everything else right now!

