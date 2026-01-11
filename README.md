# RepoWhisper

> Voice-powered code search for your local repositories. Speak your query, find code instantly.

A Mac menu bar app that listens to your voice, transcribes it in real-time, and searches your local code repositories using semantic vector search—all in under 500ms. Features a stealth overlay that's invisible to screen sharing.

![RepoWhisper](https://img.shields.io/badge/version-0.1.0-blue)
![Python](https://img.shields.io/badge/python-3.12+-green)
![Swift](https://img.shields.io/badge/swift-5.9+-orange)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

## Screenshots

### Main Interface - Voice Search Results
![Voice Search Results](assets/screenshots/main-results.png)
*Glass morphism overlay showing semantic search results with code previews*

### Ask Bar - Typed & Voice Input
![Ask Bar](assets/screenshots/ask-bar.png)
*Combined text input and voice recording with hotkey hints*

### Search History
![Search History](assets/screenshots/search-history.png)
*Collapsible recent searches for quick re-runs*

### Stealth Mode
![Stealth Mode](assets/screenshots/stealth-mode.png)
*Invisible to screen sharing - perfect for interviews*

### Menu Bar
![Menu Bar](assets/screenshots/menu-bar.png)
*Compact menu bar interface with quick actions*

### Repository Indexing
![Indexing](assets/screenshots/indexing.png)
*Smart indexing with progress indicator*

## Features

- **Real-time Voice Transcription** - Speak naturally, get instant results
- **Semantic Code Search** - Find code by meaning, not just keywords
- **Sub-500ms Latency** - Optimized for speed with Faster-Whisper and LanceDB
- **Stealth Mode** - Overlay invisible to Zoom/Teams screen sharing
- **M2/Apple Silicon Optimized** - MPS acceleration for embeddings, float16 Whisper
- **Glass Morphism UI** - Beautiful semi-transparent floating window
- **Global Hotkeys** - Control everything from keyboard
- **Launch at Login** - Auto-start with macOS
- **Silent Background Mode** - Lives in menu bar, never quits

### Indexing Modes

- **Manual** - Select specific files (fastest)
- **Smart** - Use file patterns like `*.py, *.swift` (balanced)
- **Full** - Index entire repository (comprehensive)

## Quick Start

### One-Click Build & Run

```bash
# Clone the repository
git clone https://github.com/Rahul-sch/RepoWhisper.git
cd RepoWhisper

# Build and run (includes backend option)
./run.sh              # Build and launch frontend only
./run.sh --backend    # Also start Python backend
./run.sh --clean      # Clean build (removes DerivedData)
```

### Manual Setup

#### Backend

```bash
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
python main.py
```

Backend starts at `http://127.0.0.1:8000`

#### Frontend

Open `frontend/RepoWhisper.xcodeproj` in Xcode and press `Cmd+R` to build and run.

## Hotkeys

| Hotkey | Action |
|--------|--------|
| `Cmd+Shift+R` | Toggle voice recording |
| `Cmd+Shift+Space` | Show/center overlay |
| `Cmd+B` | Toggle visibility |
| `Cmd+Shift+H` | Toggle stealth mode |
| `Cmd+Arrow Keys` | Move window |

## Stealth Mode

When stealth mode is enabled (`Cmd+Shift+H`):

- **Screen-share invisible** - Window won't appear in Zoom, Teams, or OBS
- **Mission Control hidden** - Won't show in desktop overview
- **Cmd+Tab skipped** - Won't appear in app switcher
- **Reduced opacity** - Subtle 70% transparency

Perfect for coding interviews, pair programming, or keeping your workflow private.

## Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌──────────────┐
│  SwiftUI App   │────▶│   FastAPI        │────▶│   LanceDB    │
│  (MenuBar)     │     │   Backend        │     │   Vector DB  │
│                │     │                  │     │              │
│  • AudioCapture│     │  • Whisper       │     │  • Embeddings│
│  • Stealth UI  │     │  • MPS Accel     │     │  • Search    │
│  • Hotkeys     │     │  • Indexing      │     │              │
└─────────────────┘     └──────────────────┘     └──────────────┘
```

## Tech Stack

### Backend
- **Python 3.12+** - Core runtime
- **FastAPI** - High-performance web framework
- **Faster-Whisper** - Speech-to-text (float16 on M2)
- **LanceDB** - Vector database for semantic search
- **Sentence-Transformers** - MiniLM-L6-v2 embeddings (MPS accelerated)
- **Supabase** - Authentication & database

### Frontend
- **SwiftUI** - Native macOS interface
- **AVAudioEngine** - Real-time microphone capture
- **NSPanel** - Stealth overlay with `sharingType = .none`
- **MenuBarExtra** - Menu bar integration
- **ServiceManagement** - Launch at Login

## M2/Apple Silicon Optimization

RepoWhisper is optimized for Apple Silicon:

| Component | Optimization |
|-----------|-------------|
| Embeddings | MPS (Metal) - 2-3x faster than CPU |
| Whisper | float16 compute type, 8 threads |
| Window | Native NSPanel with hardware compositing |

## Performance

| Stage | Latency |
|-------|---------|
| Audio Capture | ~100ms |
| Transcription | ~120ms (M2) |
| Embedding | ~20ms (MPS) |
| Vector Search | ~5ms |
| **Total** | **<300ms** |

## API Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| `POST` | `/index` | Index a repository |
| `POST` | `/search` | Search indexed code |
| `POST` | `/transcribe` | Transcribe audio |
| `GET` | `/health` | Health check |
| `GET` | `/repos` | List repositories |

### Example: Search Code

```bash
curl -X POST http://127.0.0.1:8000/search \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query": "authentication function", "top_k": 5}'
```

## UI Features

- **Glass Morphism** - Blurred transparent background with shimmer effect
- **Copy Button** - One-click copy code snippets to clipboard
- **Filter Toggle** - Switch between Full Repo and Active File search
- **Voice Pulse** - Real-time audio level visualization
- **Clear All** - Reset results with one click
- **Toast Notifications** - Non-intrusive error/success messages

## Project Structure

```
RepoWhisper/
├── backend/              # Python FastAPI backend
│   ├── main.py          # FastAPI app & endpoints
│   ├── search.py        # Vector search (MPS optimized)
│   ├── transcribe.py    # Whisper (M2 optimized)
│   ├── indexer.py       # Code indexing
│   └── config.py        # Settings
├── frontend/            # SwiftUI macOS app
│   └── RepoWhisper/
│       ├── RepoWhisperApp.swift       # App entry, hotkeys
│       ├── FloatingPopupManager.swift # Stealth overlay
│       ├── ResultsWindow.swift        # Glass UI
│       ├── AudioCapture.swift         # Microphone
│       └── APIClient.swift            # Backend communication
├── run.sh               # One-click build script
└── CLAUDE.md            # AI assistant workflow
```

## Configuration

Settings are persisted via UserDefaults:

- **Stealth Mode** - Remembered across sessions
- **Window Position** - Restored on launch
- **Launch at Login** - Toggle in menu bar
- **Index Mode** - Manual/Smart/Full preference

## Documentation

- [SETUP.md](SETUP.md) - Complete setup guide
- [backend/ENV_SETUP.md](backend/ENV_SETUP.md) - Environment configuration
- [frontend/XCODE_SETUP.md](frontend/XCODE_SETUP.md) - Xcode project setup
- [QUICKSTART.md](QUICKSTART.md) - Quick start guide

## Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

MIT License - see [LICENSE](LICENSE) for details.

## Acknowledgments

- [Faster-Whisper](https://github.com/guillaumekln/faster-whisper) - Fast Whisper implementation
- [LanceDB](https://lancedb.github.io/lancedb/) - Vector database
- [Sentence-Transformers](https://www.sbert.net/) - Embedding models
- [free-cluely](https://github.com/m13v/free-cluely) - Stealth overlay inspiration

---

**Made with care for developers who want to search code with their voice**
