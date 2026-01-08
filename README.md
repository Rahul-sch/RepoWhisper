# RepoWhisper 🎤

> Voice-powered code search for your local repositories. Speak your query, find code instantly.

A Mac menu bar app that listens to your voice, transcribes it in real-time, and searches your local code repositories using semantic vector search—all in under 500ms.

![RepoWhisper](https://img.shields.io/badge/version-0.1.0-blue)
![Python](https://img.shields.io/badge/python-3.12+-green)
![Swift](https://img.shields.io/badge/swift-5.9+-orange)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

## ✨ Features

- 🎙️ **Real-time Voice Transcription** - Speak naturally, get instant results
- 🔍 **Semantic Code Search** - Find code by meaning, not just keywords
- ⚡ **Sub-500ms Latency** - Optimized for speed with Faster-Whisper and LanceDB
- 🎯 **Three Indexing Modes**:
  - **Manual** - Select specific files (fastest)
  - **Guided** - Use file patterns (balanced)
  - **Full** - Index entire repository (comprehensive)
- 🔐 **User Isolation** - Each user has isolated vector stores
- 🔑 **Supabase Auth** - Secure authentication with JWT validation
- ⌨️ **Keyboard Shortcuts** - Press `⌘⇧R` to toggle recording
- 🎨 **Beautiful UI** - Semi-transparent floating results window

## 🏗️ Architecture

```
┌─────────────────┐     ┌──────────────────┐     ┌──────────────┐
│  SwiftUI App   │────▶│   FastAPI        │────▶│   LanceDB    │
│  (MenuBar)     │     │   Backend        │     │   Vector DB  │
│                 │     │                  │     │              │
│  • AudioCapture │     │  • Whisper       │     │  • Embeddings│
│  • Supabase     │     │  • Embeddings    │     │  • Search    │
│  • Results UI   │     │  • Indexing      │     │              │
└─────────────────┘     └──────────────────┘     └──────────────┘
         │                       │
         │                       │
         └───────────────────────┘
              Supabase (Auth + DB)
```

## 🛠️ Tech Stack

### Backend
- **Python 3.12+** - Core runtime
- **FastAPI** - High-performance web framework
- **Faster-Whisper** - Fast speech-to-text (tiny.en model)
- **LanceDB** - Vector database for semantic search
- **Sentence-Transformers** - MiniLM-L6-v2 embeddings
- **Supabase** - Authentication & database
- **Structlog** - Structured logging
- **SlowAPI** - Rate limiting

### Frontend
- **SwiftUI** - Native macOS interface
- **AVAudioEngine** - Real-time microphone capture
- **Supabase Swift SDK** - Authentication
- **MenuBarExtra** - Menu bar integration

### Database
- **Supabase (PostgreSQL)** - User profiles & repo metadata
- **LanceDB** - Vector embeddings storage

## 🚀 Quick Start

### Prerequisites

- Python 3.12+
- macOS 13.0+
- Xcode 15+ (for building the app)
- Supabase account and project

### Backend Setup

```bash
# Navigate to backend
cd backend

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Configure environment (see backend/ENV_SETUP.md)
cp ENV_SETUP.md .env  # Edit with your Supabase credentials

# Run the backend
python main.py
```

Backend will start at `http://127.0.0.1:8000`

### Frontend Setup

#### Option 1: Xcode (Recommended)

1. Open Xcode and create a new macOS App project
2. Follow instructions in [`frontend/XCODE_SETUP.md`](frontend/XCODE_SETUP.md)
3. Add Supabase Swift SDK via Swift Package Manager
4. Build and run (⌘R)

#### Option 2: Swift Package Manager

```bash
cd frontend
swift build
swift run RepoWhisper
```

### First Run

1. **Start the backend** (see Backend Setup above)
2. **Launch the Swift app**
3. **Sign in** with Supabase (email/password or OAuth)
4. **Select a repository** to index
5. **Choose indexing mode** (Manual/Guided/Full)
6. **Click "Start Listening"** or press `⌘⇧R`
7. **Speak your search query** and see results!

## 📚 Documentation

- **[SETUP.md](SETUP.md)** - Complete setup guide
- **[backend/ENV_SETUP.md](backend/ENV_SETUP.md)** - Environment configuration
- **[frontend/XCODE_SETUP.md](frontend/XCODE_SETUP.md)** - Xcode project setup
- **[PRODUCTION_CHECKLIST.md](PRODUCTION_CHECKLIST.md)** - Production readiness checklist
- **[CHANGELOG.md](CHANGELOG.md)** - Recent changes and updates

## 🔌 API Endpoints

### Authentication Required

| Method | Endpoint | Description | Rate Limit |
|--------|----------|-------------|------------|
| `POST` | `/index` | Index a repository | 10/min |
| `POST` | `/search` | Search indexed code | 60/min |
| `GET` | `/repos` | List user's repositories | 30/min |
| `DELETE` | `/repos/{id}` | Delete repository | 10/min |

### Optional Authentication

| Method | Endpoint | Description | Rate Limit |
|--------|----------|-------------|------------|
| `POST` | `/transcribe` | Transcribe audio | 120/min |

### Public

| Method | Endpoint | Description | Rate Limit |
|--------|----------|-------------|------------|
| `GET` | `/health` | Health check | 100/min |

### Example: Search Code

```bash
curl -X POST http://127.0.0.1:8000/search \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "query": "user authentication function",
    "top_k": 5
  }'
```

## 🎯 Indexing Modes

### Manual Mode
Select specific files to index. Fastest option for targeted searches.

```json
{
  "mode": "manual",
  "repo_path": "/path/to/repo",
  "file_paths": ["src/auth.py", "src/models/user.py"]
}
```

### Guided Mode
Use file patterns to index matching files. Balanced approach.

```json
{
  "mode": "guided",
  "repo_path": "/path/to/repo",
  "patterns": ["*.py", "src/**/*.ts", "tests/*.swift"]
}
```

### Full Mode
Index all supported file types in the repository. Most comprehensive.

```json
{
  "mode": "full",
  "repo_path": "/path/to/repo"
}
```

## 🔒 Security Features

- ✅ **User Data Isolation** - Per-user vector stores
- ✅ **JWT Authentication** - Supabase token validation
- ✅ **Rate Limiting** - Prevents abuse
- ✅ **CORS Protection** - Restricted origins
- ✅ **Input Validation** - Path sanitization, query length limits
- ✅ **Row Level Security** - Database-level access control

## 📊 Performance

- **Transcription**: ~200ms (Whisper tiny.en)
- **Embedding**: ~50ms (MiniLM-L6-v2)
- **Vector Search**: ~20ms (LanceDB ANN)
- **Total Latency**: <500ms target

## 🧪 Development

### Running Tests

```bash
# Backend tests (when implemented)
cd backend
pytest

# Frontend tests (when implemented)
cd frontend
swift test
```

### Project Structure

```
RepoWhisper/
├── backend/              # Python FastAPI backend
│   ├── main.py          # FastAPI app & endpoints
│   ├── auth.py          # JWT validation
│   ├── indexer.py       # Code indexing
│   ├── search.py        # Vector search
│   ├── transcribe.py    # Whisper integration
│   ├── supabase_client.py # Supabase operations
│   └── logger.py        # Structured logging
├── frontend/            # SwiftUI macOS app
│   └── RepoWhisper/     # Swift source files
│       ├── RepoWhisperApp.swift
│       ├── MenuBarView.swift
│       ├── AudioCapture.swift
│       ├── APIClient.swift
│       └── ...
└── docs/                # Documentation
```

## 🚢 Deployment

### Backend

Deploy to any Python hosting service:
- **Railway** - `railway up`
- **Fly.io** - `fly deploy`
- **Heroku** - `git push heroku main`
- **AWS/GCP** - Use Docker container

### Frontend

1. Build in Xcode
2. Archive the app
3. Code sign with your developer certificate
4. Distribute via:
   - App Store
   - Direct download
   - Sparkle updates

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [Faster-Whisper](https://github.com/guillaumekln/faster-whisper) - Fast Whisper implementation
- [LanceDB](https://lancedb.github.io/lancedb/) - Vector database
- [Supabase](https://supabase.com) - Backend infrastructure
- [Sentence-Transformers](https://www.sbert.net/) - Embedding models

## 📧 Support

- **Issues**: [GitHub Issues](https://github.com/Rahul-sch/RepoWhisper/issues)
- **Discussions**: [GitHub Discussions](https://github.com/Rahul-sch/RepoWhisper/discussions)

---

**Made with ❤️ for developers who want to search code with their voice**
