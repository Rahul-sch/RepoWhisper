# Boss Mode 🎯

**Meeting Intelligence for RepoWhisper**

Boss Mode combines system audio capture, screen context, and code search to generate intelligent talking points for meetings.

## Features

### 1. System Audio Capture
- Records system audio (boss/colleagues talking) using ScreenCaptureKit
- Captures alongside microphone input
- Real-time processing

### 2. Silent Screenshot Capture
- Takes screenshots of active window every 5 seconds
- Compressed JPEG format for efficiency
- No visual indication (silent)

### 3. The Advisor
- `/advise` endpoint combines:
  - Latest transcript (what was said)
  - Latest screenshot (what's on screen)
  - Relevant code snippets (from search)
- Returns concise talking points (1-2 sentences)
- Uses OpenAI GPT-4o-mini (with fallback to rule-based)

## How It Works

1. **Enable Boss Mode** - Toggle in MenuBarView
2. **Start Recording** - Begin voice capture
3. **Automatic Processing**:
   - Screenshots captured every 5s
   - Transcripts generated from audio
   - Code search runs on transcript
   - Advice generated from all context
4. **Talking Points** - Displayed in UI

## API Endpoints

### `POST /advise`
Generate talking point from context.

**Request:**
```json
{
  "transcript": "We need to optimize the authentication flow",
  "screenshot_base64": "base64_encoded_image...",
  "code_snippets": ["def authenticate_user(...)", "..."],
  "meeting_context": "Code review meeting"
}
```

**Response:**
```json
{
  "talking_point": "Based on the code structure, I think we should consider refactoring the auth flow for better performance.",
  "confidence": 0.9,
  "context": "ai_generated"
}
```

### `POST /screenshot`
Upload and process screenshot.

**Request:** Raw JPEG/PNG bytes

**Response:**
```json
{
  "success": true,
  "screenshot_base64": "base64_encoded_image...",
  "size_bytes": 12345
}
```

## Permissions Required

- **Microphone** - For voice transcription
- **Screen Recording** - For system audio and screenshots
- **Accessibility** - For identifying active window

All permissions are requested automatically when Boss Mode is enabled.

## Configuration

### OpenAI API Key (Optional)
For AI-powered talking points, set in `.env`:
```bash
OPENAI_API_KEY=your_key_here
```

If not set, falls back to rule-based talking points.

## Latency Optimization

- Screenshots processed asynchronously
- Advice generation doesn't block transcription
- Image compression reduces upload time
- Screenshot capture runs on separate timer (non-blocking)

## Usage Example

1. Join a meeting
2. Enable Boss Mode toggle
3. Start listening (⌘⇧R)
4. Speak or let others speak
5. View generated talking points in real-time
6. Use talking points to contribute meaningfully!

## Technical Details

- **Screenshot Format**: JPEG, 0.7 quality, max 1024px width
- **Screenshot Interval**: 5 seconds
- **Audio Format**: 16kHz mono PCM16 (same as transcription)
- **Rate Limits**: 
  - `/advise`: 30 requests/minute
  - `/screenshot`: 60 requests/minute

## Future Enhancements

- [ ] Multi-window screenshot selection
- [ ] Meeting transcript history
- [ ] Custom talking point styles
- [ ] Integration with calendar for context
- [ ] Voice activity detection for smarter advice timing

