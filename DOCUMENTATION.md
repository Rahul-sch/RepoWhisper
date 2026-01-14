# RepoWhisper - Comprehensive Technical Documentation

> Complete technical reference for the voice-powered code search application

---

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Architecture](#2-architecture)
3. [Frontend (SwiftUI/macOS)](#3-frontend-swiftuimacos)
4. [Backend (Python/FastAPI)](#4-backend-pythonfastapi)
5. [Core Features](#5-core-features)
6. [UI Components](#6-ui-components)
7. [Stealth Mode System](#7-stealth-mode-system)
8. [Voice & Audio Pipeline](#8-voice--audio-pipeline)
9. [Search & Indexing](#9-search--indexing)
10. [Authentication System](#10-authentication-system)
11. [Persistence & Settings](#11-persistence--settings)
12. [Global Hotkeys](#12-global-hotkeys)
13. [Performance Optimizations](#13-performance-optimizations)
14. [API Reference](#14-api-reference)
15. [File Structure](#15-file-structure)
16. [Build & Deployment](#16-build--deployment)

---

## 1. Project Overview

### What is RepoWhisper?

RepoWhisper is a native macOS menu bar application that enables developers to search their local code repositories using voice commands. It combines:

- **Real-time speech-to-text** using Faster-Whisper
- **Semantic vector search** using LanceDB and Sentence-Transformers
- **Stealth overlay UI** invisible to screen sharing applications
- **Glass morphism design** with modern SwiftUI components

### Key Metrics

| Metric | Target | Achieved |
|--------|--------|----------|
| End-to-end latency | <500ms | ~295ms |
| Audio capture | <100ms | ~100ms |
| Transcription (M2) | <150ms | ~120ms |
| Embedding generation | <50ms | ~20ms (MPS) |
| Vector search | <10ms | ~5ms |

### Technology Stack

**Frontend:**
- Swift 5.9+
- SwiftUI
- AppKit (NSPanel, NSWindow)
- AVAudioEngine
- ServiceManagement (Launch at Login)

**Backend:**
- Python 3.12+
- FastAPI
- Faster-Whisper (float16 on ARM)
- Sentence-Transformers (MPS accelerated)
- LanceDB (vector database)
- Supabase (authentication & cloud sync)

---

## 2. Architecture

### System Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           macOS Menu Bar                                │
│                         ┌──────────────┐                                │
│                         │ RepoWhisper  │                                │
│                         │   (Swift)    │                                │
│                         └──────┬───────┘                                │
│                                │                                        │
│  ┌─────────────────────────────┼─────────────────────────────────────┐  │
│  │                             ▼                                     │  │
│  │  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐   │  │
│  │  │AudioCapture  │───▶│  APIClient   │───▶│FloatingPopup     │   │  │
│  │  │(AVAudioEngine)    │  (URLSession)│    │Manager (NSPanel) │   │  │
│  │  └──────────────┘    └──────┬───────┘    └──────────────────┘   │  │
│  │                             │                                     │  │
│  │                             ▼                                     │  │
│  │                      ┌──────────────┐                            │  │
│  │                      │  ResultsWindow                            │  │
│  │                      │  (SwiftUI)   │                            │  │
│  │                      └──────────────┘                            │  │
│  │                                                                   │  │
│  │  Frontend (Swift/SwiftUI)                                        │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                │                                        │
│                                │ HTTP/REST                              │
│                                ▼                                        │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │                             │                                     │  │
│  │  ┌──────────────┐    ┌──────────────┐    ┌──────────────────┐   │  │
│  │  │ transcribe.py│    │  search.py   │    │   indexer.py     │   │  │
│  │  │(Faster-Whisper)   │(SentenceTrans)    │   (Chunking)     │   │  │
│  │  └──────────────┘    └──────┬───────┘    └──────────────────┘   │  │
│  │                             │                                     │  │
│  │                             ▼                                     │  │
│  │                      ┌──────────────┐                            │  │
│  │                      │   LanceDB    │                            │  │
│  │                      │ (Vector DB)  │                            │  │
│  │                      └──────────────┘                            │  │
│  │                                                                   │  │
│  │  Backend (Python/FastAPI)                                        │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### Data Flow

1. **Voice Input Flow:**
   ```
   Microphone → AVAudioEngine → PCM Buffer → WAV File →
   POST /transcribe → Faster-Whisper → Text Query
   ```

2. **Search Flow:**
   ```
   Text Query → POST /search → Sentence-Transformers (MPS) →
   Embedding Vector → LanceDB Search → Top-K Results →
   ResultsWindow Display
   ```

3. **Indexing Flow:**
   ```
   Repository Path → File Discovery → Chunking (by function/class) →
   Embedding Generation → LanceDB Insert → Index Complete
   ```

---

## 3. Frontend (SwiftUI/macOS)

### Entry Point

**File:** `RepoWhisperApp.swift`

```swift
@main
struct RepoWhisperApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            Image(systemName: "waveform.circle.fill")
        }
        .menuBarExtraStyle(.window)
    }
}
```

### AppDelegate Responsibilities

- **Global hotkey registration** via `NSEvent.addGlobalMonitorForEvents`
- **Silent background mode** - app continues running when main window closes
- **Launch at Login** integration via `SMAppService`
- **Accessibility permissions** handling

### Key Swift Files

| File | Purpose | Lines |
|------|---------|-------|
| `RepoWhisperApp.swift` | App entry, scene definition | ~150 |
| `FloatingPopupManager.swift` | Popup window management, stealth mode | ~505 |
| `ResultsWindow.swift` | Main results UI, all components | ~1223 |
| `AudioCapture.swift` | Microphone capture, VAD | ~200 |
| `APIClient.swift` | HTTP client, endpoint wrappers | ~300 |
| `AuthManager.swift` | Supabase authentication | ~250 |
| `AnimationHelpers.swift` | Custom animations, gradients | ~260 |
| `SupabaseConfig.swift` | Supabase client configuration | ~60 |

---

## 4. Backend (Python/FastAPI)

### Server Configuration

**File:** `main.py`

```python
from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="RepoWhisper API", version="0.1.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
```

### Key Python Files

| File | Purpose |
|------|---------|
| `main.py` | FastAPI app, routes, middleware |
| `search.py` | Vector search, embedding generation |
| `transcribe.py` | Whisper model, audio processing |
| `indexer.py` | Code chunking, file parsing |
| `config.py` | Settings, environment variables |
| `auth.py` | JWT validation, Supabase integration |

### Startup Sequence

1. Load Faster-Whisper model (float16 on ARM)
2. Initialize Sentence-Transformers (MPS device)
3. Connect to LanceDB
4. Start uvicorn server on `127.0.0.1:8000`

---

## 5. Core Features

### 5.1 Voice Search

**Implementation:**

```swift
// AudioCapture.swift
class AudioCapture: ObservableObject {
    private var audioEngine: AVAudioEngine
    private var inputNode: AVAudioInputNode

    func startRecording() {
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
            // Process audio buffer
            self.processAudioBuffer(buffer)
        }
        try audioEngine.start()
    }
}
```

**Audio Format:**
- Sample rate: 16kHz (Whisper requirement)
- Channels: Mono
- Bit depth: 16-bit PCM
- Container: WAV

### 5.2 Semantic Code Search

**Vector Embedding:**
- Model: `all-MiniLM-L6-v2`
- Dimensions: 384
- Device: MPS (Metal Performance Shaders)

**Search Algorithm:**
```python
# search.py
def search(query: str, top_k: int = 5) -> List[SearchResult]:
    # Generate query embedding
    embedding = model.encode(query, device=get_device())

    # Search LanceDB
    results = table.search(embedding).limit(top_k).to_list()

    return [SearchResult(**r) for r in results]
```

### 5.3 Code Indexing

**Chunking Strategy:**
- Function-level chunking for Python/Swift/JS
- Class-level chunking for OOP languages
- Fixed-size fallback (500 tokens) for other files

**Supported Languages:**
- Python (`.py`)
- Swift (`.swift`)
- JavaScript/TypeScript (`.js`, `.ts`, `.tsx`)
- Go (`.go`)
- Rust (`.rs`)
- Java (`.java`)
- C/C++ (`.c`, `.cpp`, `.h`)

### 5.4 Typed Search

**AskBar Component:**

```swift
struct AskBar: View {
    @Binding var query: String
    let isRecording: Bool
    let audioLevel: Float
    let onSubmit: (String) -> Void
    let onToggleRecording: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Search text field
            TextField("What code are you searching for?", text: $query)
                .onSubmit {
                    onSubmit(query)
                }

            // Mic button with hotkey badge
            AskBarMicButton(...)
        }
    }
}
```

### 5.5 Search History

**Data Model:**

```swift
struct SearchHistoryItem: Codable, Identifiable {
    let id: UUID
    let query: String
    let resultsCount: Int
    let timestamp: Date

    var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: timestamp, relativeTo: Date())
    }
}
```

**Persistence:**
- Local: UserDefaults (JSON encoded)
- Cloud: Supabase `search_history` table (optional)
- Max items: 10 (LIFO)
- Deduplication: Case-insensitive query matching

---

## 6. UI Components

### 6.1 ResultsWindow

The main floating overlay displaying search results.

**Structure:**
```
┌─────────────────────────────────────────┐
│ [Drag Area - 44px]                      │
├─────────────────────────────────────────┤
│ [AskBar - Search Input + Mic Button]    │
├─────────────────────────────────────────┤
│ [HeaderView - Query + Latency + Status] │
├─────────────────────────────────────────┤
│ [SearchHistoryView - Collapsible]       │
├─────────────────────────────────────────┤
│ [Results List / Loading / Empty State]  │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ PremiumResultCard #1            │   │
│  │ • File name + line numbers      │   │
│  │ • Code preview (syntax colored) │   │
│  │ • Score badge + copy button     │   │
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ PremiumResultCard #2            │   │
│  └─────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘
```

**Dimensions:**
- Width: 580px
- Height: 520px (adjustable)
- Corner radius: 22px

### 6.2 PremiumResultCard

Displays a single search result with code preview.

**Features:**
- Rank badge (#1, #2, #3 with gold/silver/bronze colors)
- File name with icon
- Line number range
- Relevance score (percentage)
- Syntax-highlighted code preview
- Copy-to-clipboard button (hover reveal)
- Full file path (truncated)

### 6.3 AskBar

Combined text input and voice recording interface.

**Components:**
- Search icon (magnifying glass)
- Text field with placeholder
- Clear button (X icon, appears when text present)
- Mic button with:
  - Pulse rings during recording
  - Audio level visualization
  - Hotkey badge (⌘⇧R)

### 6.4 SearchHistoryView

Collapsible panel showing recent searches.

**Features:**
- Chevron toggle (expand/collapse)
- Item count badge
- Clear button (when expanded)
- History rows with:
  - Clock icon
  - Query text
  - Results count badge
  - Relative timestamp ("2m ago")

### 6.5 SkeletonLoading

Loading placeholder with shimmer animation.

**Structure:**
- 3 skeleton cards
- Decreasing opacity (1.0, 0.85, 0.70)
- Animated shimmer gradient
- Matches PremiumResultCard layout

### 6.6 ToastView

Non-intrusive notification overlay.

**Properties:**
- Position: Top of window
- Animation: Slide down + fade
- Auto-dismiss: 3 seconds
- Styling: Glass morphism background

### 6.7 WaveformAnimation

Animated waveform indicator for recording state.

**Animation:**
- 5 bars with varying heights
- Phase-shifted sine wave animation
- Color: Purple to blue gradient

### 6.8 VoicePulseButton

Main voice recording toggle button.

**States:**
- Idle: Gray mic icon
- Hover: Lighter background
- Recording: Red with pulse rings
- Audio level: Ring size responds to volume

### 6.9 FilterToggle

Toggle between search scopes.

**Options:**
- Full Repo: Search entire indexed repository
- Active File: Search current file only (future feature)

---

## 7. Stealth Mode System

### Overview

Stealth mode makes the overlay window invisible to screen sharing applications (Zoom, Teams, OBS, etc.) while remaining visible locally.

### Implementation

**NSPanel Configuration:**

```swift
// FloatingPopupManager.swift
func configureStealthMode() {
    guard let panel = popupWindow else { return }

    if isStealthMode {
        // Screen-share invisibility
        panel.sharingType = .none

        // Hidden from Mission Control
        panel.collectionBehavior.insert(.stationary)

        // Skip Cmd+Tab
        panel.collectionBehavior.insert(.ignoresCycle)

        // Reduced opacity
        panel.animator().alphaValue = 0.7

        // No shadow
        panel.hasShadow = false
    } else {
        // Normal mode - shareable
        panel.sharingType = .readOnly
        panel.collectionBehavior.remove(.stationary)
        panel.collectionBehavior.remove(.ignoresCycle)
        panel.animator().alphaValue = 1.0
        panel.hasShadow = true
    }
}
```

### Key Properties

| Property | Stealth | Normal |
|----------|---------|--------|
| `sharingType` | `.none` | `.readOnly` |
| `collectionBehavior` | `.stationary`, `.ignoresCycle` | Default |
| `alphaValue` | 0.7 | 1.0 |
| `hasShadow` | false | true |
| Window level | `.statusBar + 1` | `.floating` |

### Activation

- **Hotkey:** ⌘⇧H (Command + Shift + H)
- **Persistence:** Saved to UserDefaults, restored on app launch

### Verification

To test stealth mode:
1. Start Zoom/Teams screen share
2. Toggle stealth mode (⌘⇧H)
3. Verify overlay is NOT visible to remote participants
4. Verify overlay IS visible locally

---

## 8. Voice & Audio Pipeline

### 8.1 Audio Capture

**File:** `AudioCapture.swift`

```swift
class AudioCapture: ObservableObject {
    static let shared = AudioCapture()

    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0

    private var audioEngine: AVAudioEngine!
    private var inputNode: AVAudioInputNode!
    private var audioFile: AVAudioFile?

    func startRecording() async -> Bool {
        // Request microphone permission
        let granted = await requestPermission()
        guard granted else { return false }

        // Configure audio session
        let format = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: 16000,
            channels: 1,
            interleaved: false
        )!

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            self.processBuffer(buffer)
        }

        try audioEngine.start()
        isRecording = true
        return true
    }

    func stopRecording() -> URL? {
        inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRecording = false
        return audioFileURL
    }
}
```

### 8.2 Audio Level Monitoring

Real-time audio level for UI visualization:

```swift
private func processBuffer(_ buffer: AVAudioPCMBuffer) {
    guard let channelData = buffer.floatChannelData?[0] else { return }
    let frameLength = Int(buffer.frameLength)

    // Calculate RMS (Root Mean Square)
    var sum: Float = 0
    for i in 0..<frameLength {
        sum += channelData[i] * channelData[i]
    }
    let rms = sqrt(sum / Float(frameLength))

    // Normalize to 0-1 range
    let normalizedLevel = min(1.0, rms * 10)

    DispatchQueue.main.async {
        self.audioLevel = normalizedLevel
    }
}
```

### 8.3 Transcription (Backend)

**File:** `transcribe.py`

```python
from faster_whisper import WhisperModel
import platform

# M2 optimization
compute_type = "float16" if platform.processor() == "arm" else "int8"
cpu_threads = 8 if platform.processor() == "arm" else 4

model = WhisperModel(
    "base.en",  # English-only for speed
    device="cpu",
    compute_type=compute_type,
    cpu_threads=cpu_threads
)

async def transcribe(audio_file: UploadFile) -> str:
    # Save uploaded file
    temp_path = f"/tmp/{uuid4()}.wav"
    with open(temp_path, "wb") as f:
        f.write(await audio_file.read())

    # Transcribe
    segments, info = model.transcribe(
        temp_path,
        beam_size=1,  # Faster, slightly less accurate
        language="en",
        vad_filter=True  # Voice activity detection
    )

    # Combine segments
    text = " ".join([seg.text for seg in segments])

    # Cleanup
    os.remove(temp_path)

    return text.strip()
```

### 8.4 Voice Activity Detection (VAD)

Built into Faster-Whisper:
- Silero VAD model
- Filters out silence/noise
- Reduces transcription latency

---

## 9. Search & Indexing

### 9.1 Code Chunking

**File:** `indexer.py`

```python
def chunk_code(file_path: str, content: str) -> List[CodeChunk]:
    """Split code into semantic chunks (functions, classes)."""

    extension = Path(file_path).suffix
    chunks = []

    if extension == ".py":
        chunks = chunk_python(content)
    elif extension == ".swift":
        chunks = chunk_swift(content)
    elif extension in [".js", ".ts", ".tsx"]:
        chunks = chunk_javascript(content)
    else:
        # Fallback: fixed-size chunks
        chunks = chunk_fixed_size(content, max_tokens=500)

    return chunks

def chunk_python(content: str) -> List[CodeChunk]:
    """Extract functions and classes from Python code."""
    import ast

    tree = ast.parse(content)
    chunks = []

    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            start_line = node.lineno
            end_line = node.end_lineno
            chunk_content = "\n".join(content.split("\n")[start_line-1:end_line])

            chunks.append(CodeChunk(
                content=chunk_content,
                line_start=start_line,
                line_end=end_line,
                type="function" if isinstance(node, ast.FunctionDef) else "class"
            ))

    return chunks
```

### 9.2 Embedding Generation

**File:** `search.py`

```python
from sentence_transformers import SentenceTransformer
import torch

def get_device() -> str:
    """Get optimal device for embeddings."""
    if torch.backends.mps.is_available():
        return "mps"  # Apple Silicon GPU
    elif torch.cuda.is_available():
        return "cuda"
    return "cpu"

# Initialize model with MPS
model = SentenceTransformer(
    "all-MiniLM-L6-v2",
    device=get_device()
)

def generate_embedding(text: str) -> List[float]:
    """Generate 384-dimensional embedding for text."""
    embedding = model.encode(
        text,
        convert_to_numpy=True,
        normalize_embeddings=True
    )
    return embedding.tolist()
```

### 9.3 LanceDB Storage

```python
import lancedb

# Connect to database
db = lancedb.connect("./data/lancedb")

# Create or open table
def create_index(repo_path: str, chunks: List[CodeChunk]):
    table_name = sanitize_table_name(repo_path)

    data = []
    for chunk in chunks:
        embedding = generate_embedding(chunk.content)
        data.append({
            "file_path": chunk.file_path,
            "content": chunk.content,
            "line_start": chunk.line_start,
            "line_end": chunk.line_end,
            "embedding": embedding
        })

    # Create or overwrite table
    table = db.create_table(table_name, data, mode="overwrite")

    return len(data)
```

### 9.4 Vector Search

```python
def search(query: str, repo_path: str, top_k: int = 5) -> List[SearchResult]:
    """Search indexed repository using semantic similarity."""

    # Generate query embedding
    query_embedding = generate_embedding(query)

    # Get table
    table_name = sanitize_table_name(repo_path)
    table = db.open_table(table_name)

    # Perform search
    results = table.search(query_embedding) \
        .limit(top_k) \
        .select(["file_path", "content", "line_start", "line_end"]) \
        .to_list()

    # Calculate scores (cosine similarity)
    return [
        SearchResult(
            file_path=r["file_path"],
            chunk=r["content"],
            line_start=r["line_start"],
            line_end=r["line_end"],
            score=1 - r["_distance"]  # Convert distance to similarity
        )
        for r in results
    ]
```

### 9.5 Indexing Modes

| Mode | Description | Use Case |
|------|-------------|----------|
| **Manual** | Select specific files | Small, focused searches |
| **Smart** | File patterns (`*.py, *.swift`) | Balanced approach |
| **Full** | Entire repository | Comprehensive coverage |

---

## 10. Authentication System

### 10.1 Supabase Integration

**File:** `SupabaseConfig.swift`

```swift
import Supabase

enum SupabaseConfig {
    static let url = URL(string: "https://kjpxpppaeydireznlzwe.supabase.co")!
    static let anonKey = "eyJhbGciOiJIUzI1NiIs..."
    static let backendURL = URL(string: "http://127.0.0.1:8000")!
}

// Custom storage to avoid keychain prompts
final class UserDefaultsStorage: AuthLocalStorage {
    private let defaults = UserDefaults.standard

    func store(key: String, value: Data) throws {
        defaults.set(value, forKey: key)
    }

    func retrieve(key: String) throws -> Data? {
        return defaults.data(forKey: key)
    }

    func remove(key: String) throws {
        defaults.removeObject(forKey: key)
    }
}

let supabase = SupabaseClient(
    supabaseURL: SupabaseConfig.url,
    supabaseKey: SupabaseConfig.anonKey,
    options: SupabaseClientOptions(
        auth: SupabaseClientOptions.AuthOptions(
            storage: UserDefaultsStorage()
        )
    )
)
```

### 10.2 AuthManager

**File:** `AuthManager.swift`

```swift
@MainActor
class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false

    func signIn(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let session = try await supabase.auth.signIn(
            email: email,
            password: password
        )

        currentUser = session.user
        isAuthenticated = true
    }

    func signUp(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let session = try await supabase.auth.signUp(
            email: email,
            password: password
        )

        currentUser = session.user
        isAuthenticated = true
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
        currentUser = nil
        isAuthenticated = false
    }

    func restoreSession() async {
        do {
            let session = try await supabase.auth.session
            currentUser = session.user
            isAuthenticated = true
        } catch {
            isAuthenticated = false
        }
    }
}
```

### 10.3 Testing Mode

For development without authentication:

```swift
// In AppDelegate or Debug menu
#if DEBUG
func enableTestingMode() {
    AuthManager.shared.isAuthenticated = true
    AuthManager.shared.currentUser = User(
        id: UUID(),
        email: "test@example.com"
    )
}
#endif
```

---

## 11. Persistence & Settings

### 11.1 UserDefaults Keys

**File:** `FloatingPopupManager.swift`

```swift
private enum Keys {
    static let stealthMode = "RepoWhisper.stealthMode"
    static let windowX = "RepoWhisper.windowX"
    static let windowY = "RepoWhisper.windowY"
    static let hasCustomPosition = "RepoWhisper.hasCustomPosition"
    static let searchHistory = "RepoWhisper.searchHistory"
}
```

### 11.2 Persisted Settings

| Setting | Key | Type | Default |
|---------|-----|------|---------|
| Stealth mode | `stealthMode` | Bool | false |
| Window X position | `windowX` | Double | Center |
| Window Y position | `windowY` | Double | Center |
| Has custom position | `hasCustomPosition` | Bool | false |
| Search history | `searchHistory` | Data (JSON) | [] |
| Launch at login | `launchAtLogin` | Bool | false |

### 11.3 Window Position Persistence

```swift
// Save position when window moves
private func saveWindowPosition() {
    guard let panel = popupWindow else { return }
    let origin = panel.frame.origin

    UserDefaults.standard.set(origin.x, forKey: Keys.windowX)
    UserDefaults.standard.set(origin.y, forKey: Keys.windowY)
    UserDefaults.standard.set(true, forKey: Keys.hasCustomPosition)

    savedPosition = origin
}

// Restore position on init
private func loadSavedPosition() {
    if UserDefaults.standard.bool(forKey: Keys.hasCustomPosition) {
        let x = UserDefaults.standard.double(forKey: Keys.windowX)
        let y = UserDefaults.standard.double(forKey: Keys.windowY)
        savedPosition = NSPoint(x: x, y: y)
    }
}
```

### 11.4 Search History Persistence

```swift
// Save history
private func saveSearchHistoryLocal() {
    do {
        let data = try JSONEncoder().encode(searchHistory)
        UserDefaults.standard.set(data, forKey: Keys.searchHistory)
    } catch {
        print("Failed to encode search history: \(error)")
    }
}

// Load history
private func loadSearchHistory() {
    guard let data = UserDefaults.standard.data(forKey: Keys.searchHistory) else {
        searchHistory = []
        return
    }

    do {
        searchHistory = try JSONDecoder().decode([SearchHistoryItem].self, from: data)
    } catch {
        searchHistory = []
    }
}
```

---

## 12. Global Hotkeys

### 12.1 Registration

**File:** `RepoWhisperApp.swift` (AppDelegate)

```swift
func setupGlobalHotkeys() {
    // ⌘⇧R - Toggle recording
    NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
        if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 0x0F {
            self.toggleRecording()
        }
    }

    // ⌘⇧Space - Show/center overlay
    addHotkey(modifiers: [.command, .shift], keyCode: 0x31) {
        FloatingPopupManager.shared.centerAndShow()
    }

    // ⌘B - Toggle visibility
    addHotkey(modifiers: [.command], keyCode: 0x0B) {
        FloatingPopupManager.shared.toggleVisibility()
    }

    // ⌘⇧H - Toggle stealth mode
    addHotkey(modifiers: [.command, .shift], keyCode: 0x04) {
        FloatingPopupManager.shared.toggleStealthMode()
    }

    // ⌘+Arrow keys - Move window
    addHotkey(modifiers: [.command], keyCode: 0x7B) { // Left
        FloatingPopupManager.shared.moveWindow(direction: NSPoint(x: -50, y: 0))
    }
    addHotkey(modifiers: [.command], keyCode: 0x7C) { // Right
        FloatingPopupManager.shared.moveWindow(direction: NSPoint(x: 50, y: 0))
    }
    addHotkey(modifiers: [.command], keyCode: 0x7E) { // Up
        FloatingPopupManager.shared.moveWindow(direction: NSPoint(x: 0, y: 50))
    }
    addHotkey(modifiers: [.command], keyCode: 0x7D) { // Down
        FloatingPopupManager.shared.moveWindow(direction: NSPoint(x: 0, y: -50))
    }
}
```

### 12.2 Hotkey Reference

| Hotkey | Key Code | Action |
|--------|----------|--------|
| ⌘⇧R | 0x0F (R) | Toggle voice recording |
| ⌘⇧Space | 0x31 (Space) | Show and center overlay |
| ⌘B | 0x0B (B) | Toggle visibility |
| ⌘⇧H | 0x04 (H) | Toggle stealth mode |
| ⌘← | 0x7B (Left) | Move window left 50px |
| ⌘→ | 0x7C (Right) | Move window right 50px |
| ⌘↑ | 0x7E (Up) | Move window up 50px |
| ⌘↓ | 0x7D (Down) | Move window down 50px |

### 12.3 Accessibility Permissions

Global hotkeys require Accessibility permissions:

1. System Preferences → Security & Privacy → Privacy
2. Select "Accessibility" from left sidebar
3. Add RepoWhisper to allowed apps
4. Restart app if needed

---

## 13. Performance Optimizations

### 13.1 M2/Apple Silicon

**Embedding Generation (MPS):**
```python
# search.py
def get_device() -> str:
    if torch.backends.mps.is_available():
        return "mps"  # 2-3x faster than CPU
    return "cpu"

model = SentenceTransformer("all-MiniLM-L6-v2", device=get_device())
```

**Whisper Transcription (float16):**
```python
# transcribe.py
import platform

compute_type = "float16" if platform.processor() == "arm" else "int8"
cpu_threads = 8 if platform.processor() == "arm" else 4

model = WhisperModel(
    "base.en",
    device="cpu",
    compute_type=compute_type,
    cpu_threads=cpu_threads
)
```

### 13.2 Latency Optimizations

| Optimization | Before | After |
|--------------|--------|-------|
| MPS embeddings | ~50ms | ~20ms |
| float16 Whisper | ~150ms | ~120ms |
| Beam size 1 | ~200ms | ~120ms |
| VAD filter | ~150ms | ~100ms |

### 13.3 Memory Management

- **Audio buffers:** Reused, not reallocated
- **Embedding cache:** LRU cache for frequent queries
- **Window recycling:** Single NSPanel instance, content swapped

### 13.4 UI Performance

- **Skeleton loading:** Prevents layout jumps
- **Lazy loading:** Results rendered on demand
- **Animation optimization:** Hardware-accelerated with `.animation()`
- **Debounced updates:** Audio level updates throttled

---

## 14. API Reference

### 14.1 Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check, backend status |
| POST | `/transcribe` | Transcribe audio file to text |
| POST | `/search` | Search indexed repository |
| POST | `/index` | Index a repository |
| GET | `/repos` | List indexed repositories |
| DELETE | `/repos/{name}` | Delete repository index |

### 14.2 Request/Response Schemas

**POST /transcribe**

Request:
```
Content-Type: multipart/form-data
Body: audio file (WAV, 16kHz mono)
```

Response:
```json
{
    "text": "search for authentication function",
    "duration_ms": 120.5
}
```

**POST /search**

Request:
```json
{
    "query": "authentication function",
    "repo_path": "/path/to/repo",
    "top_k": 5
}
```

Response:
```json
{
    "results": [
        {
            "file_path": "/path/to/repo/auth.py",
            "chunk": "def authenticate_user(...)...",
            "line_start": 45,
            "line_end": 62,
            "score": 0.92
        }
    ],
    "latency_ms": 45.2
}
```

**POST /index**

Request:
```json
{
    "repo_path": "/path/to/repo",
    "mode": "smart",
    "patterns": ["*.py", "*.swift"]
}
```

Response:
```json
{
    "success": true,
    "chunks_indexed": 156,
    "files_processed": 42,
    "duration_ms": 3250.5
}
```

### 14.3 Error Responses

```json
{
    "detail": "Repository not found",
    "status_code": 404
}
```

---

## 15. File Structure

```
RepoWhisper/
├── backend/                      # Python FastAPI backend
│   ├── main.py                  # FastAPI app, routes
│   ├── search.py                # Vector search, embeddings
│   ├── transcribe.py            # Whisper transcription
│   ├── indexer.py               # Code chunking, parsing
│   ├── config.py                # Settings, env vars
│   ├── auth.py                  # JWT validation
│   ├── requirements.txt         # Python dependencies
│   └── data/                    # LanceDB storage
│       └── lancedb/
│
├── frontend/                     # SwiftUI macOS app
│   ├── RepoWhisper.xcodeproj    # Xcode project
│   └── RepoWhisper/
│       ├── RepoWhisperApp.swift       # App entry, AppDelegate
│       ├── FloatingPopupManager.swift # Popup window, stealth
│       ├── ResultsWindow.swift        # Main UI, components
│       ├── AudioCapture.swift         # Microphone capture
│       ├── APIClient.swift            # HTTP client
│       ├── AuthManager.swift          # Supabase auth
│       ├── SupabaseConfig.swift       # Supabase client
│       ├── AnimationHelpers.swift     # Animations, gradients
│       ├── MenuBarView.swift          # Menu bar interface
│       ├── RepoManagerView.swift      # Repository management
│       ├── OnboardingView.swift       # First-run experience
│       ├── Info.plist                 # App configuration
│       └── Assets.xcassets            # Images, colors
│
├── assets/                       # Documentation assets
│   └── screenshots/             # App screenshots
│
├── CLAUDE.md                    # AI assistant workflow
├── DOCUMENTATION.md             # This file
├── README.md                    # Project overview
├── QUICKSTART.md                # Quick start guide
├── SETUP.md                     # Detailed setup guide
├── run.sh                       # Build & run script
└── .gitignore
```

---

## 16. Build & Deployment

### 16.1 Prerequisites

**macOS:**
- macOS 14.0+ (Sonoma)
- Xcode 15.0+
- Command Line Tools

**Python:**
- Python 3.12+
- pip
- virtualenv (recommended)

### 16.2 Backend Setup

```bash
cd backend

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Start server
python main.py
```

Server starts at `http://127.0.0.1:8000`

### 16.3 Frontend Setup

```bash
cd frontend

# Open in Xcode
open RepoWhisper.xcodeproj

# Or build from command line
xcodebuild -project RepoWhisper.xcodeproj \
           -scheme RepoWhisper \
           -configuration Debug \
           build
```

### 16.4 One-Click Build

```bash
# From project root
./run.sh              # Build and launch frontend only
./run.sh --backend    # Also start Python backend
./run.sh --clean      # Clean build (removes DerivedData)
```

### 16.5 Code Signing

For development:
- "Sign to Run Locally" (automatic)

For distribution:
- Requires Apple Developer account
- Configure signing certificate in Xcode
- Enable Hardened Runtime
- Notarize for Gatekeeper

### 16.6 Permissions Required

| Permission | Purpose | How to Grant |
|------------|---------|--------------|
| Microphone | Voice recording | System prompt on first use |
| Accessibility | Global hotkeys | System Preferences → Privacy |
| Full Disk Access | Repository indexing | System Preferences → Privacy |

---

## Appendix A: Troubleshooting

### A.1 Common Issues

**"Backend offline" toast:**
- Ensure Python backend is running: `python main.py`
- Check port 8000 is not in use

**Hotkeys not working:**
- Grant Accessibility permission
- Restart app after granting

**No audio capture:**
- Grant Microphone permission
- Check System Preferences → Privacy → Microphone

**Slow transcription:**
- Ensure using M2/Apple Silicon
- Check `float16` compute type is active

### A.2 Debug Logging

Enable verbose logging:

```swift
// FloatingPopupManager.swift
print("🎯 [POPUP] showPopup called with \(results.count) results")
print("⚙️ [POPUP] Loaded settings: stealth=\(isStealthMode)")
print("⌨️ [POPUP] Typed search triggered: '\(query)'")
```

---

## Appendix B: Future Enhancements

### Planned Features

1. **Active File Search** - Search only current file in IDE
2. **Code Actions** - Open file at line number in editor
3. **Multi-repo Support** - Search across multiple repositories
4. **Custom Embeddings** - Fine-tuned model for code
5. **Offline Mode** - Local-only operation without backend
6. **VS Code Extension** - Direct IDE integration

### Performance Targets

- Sub-200ms end-to-end latency
- Support for 100k+ file repositories
- Real-time streaming transcription

---

*Documentation last updated: January 2026*
*RepoWhisper v0.1.0*
