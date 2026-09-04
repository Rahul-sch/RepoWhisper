# RepoWhisper

RepoWhisper is a local-first macOS menu-bar assistant for voice-powered semantic code search. The SwiftUI app owns repository approval, microphone and screen permissions, launches a bundled FastAPI sidecar over a private Unix-domain socket, and stores embeddings locally in LanceDB.

## What works

- Manual, glob-based, and full-repository indexing
- Live microphone transcription and encoded audio-file transcription
- Semantic search scoped to approved repositories
- A floating results overlay with global keyboard shortcuts
- Boss Mode meeting context and optional Groq-generated talking points
- Local OCR plus source-grounded explanation of visible code
- Runtime allowlist updates when repositories are added or removed

Source files larger than 2 MiB, binary files, and symlinks that escape an approved repository are not indexed. Requests are authenticated with a per-launch token and travel only through a user-private Unix socket.

## Requirements

- macOS 14 or newer
- Xcode 15 or newer
- Python 3.12 for backend development or packaging
- Microphone permission; Screen Recording permission for Boss Mode and Explain Visible

## Run from source

```bash
git clone https://github.com/Rahul-sch/RepoWhisper.git
cd RepoWhisper/backend
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cd ../frontend
./setup_xcode.sh
swift build
```

Open `frontend/RepoWhisper.xcodeproj` and run the `RepoWhisper` scheme. The app launches the backend itself after the first repository is approved; do not start a TCP server separately.

## Keyboard shortcuts

| Shortcut | Action |
| --- | --- |
| `Cmd+Shift+R` | Toggle voice recording |
| `Cmd+Shift+E` | Explain visible code |
| `Cmd+Shift+Space` | Center the overlay |
| `Cmd+B` | Toggle overlay visibility |
| `Cmd+Shift+H` | Toggle stealth mode |
| `Cmd+Arrow` | Move the overlay |

## Configuration and packaging

The core application requires no cloud account. Optional environment variables are documented in [backend/ENV_SETUP.md](backend/ENV_SETUP.md).

```bash
source backend/.venv/bin/activate
./build_binaries.sh
./prebake_models.sh       # optional offline model bundle
```

Release builds fail when the architecture-matched backend executable is missing. The Xcode build phase embeds the staged backend and optional model cache automatically. See [DEPLOYMENT.md](DEPLOYMENT.md) for signing, notarization, and DMG steps.

## Verify

```bash
./test.sh
```

CI performs the supported Python 3.12 and macOS checks on every push and pull request.

```text
SwiftUI app
  ├─ approved-folder bookmarks and allowlist
  ├─ microphone / local OCR / floating overlay
  └─ private Unix-domain socket + launch token
       └─ FastAPI sidecar
            ├─ Faster-Whisper
            ├─ sentence-transformers
            └─ per-user LanceDB storage
```

See [backend/README.md](backend/README.md), [BOSS_MODE.md](BOSS_MODE.md), and [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for focused details.
