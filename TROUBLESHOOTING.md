# Troubleshooting Guide

> **Backend startup is automatic.** The macOS app spawns the backend
> as a subprocess once you've approved at least one repo folder.
> There is no manual `./START_BACKEND.sh` step anymore — that script
> was removed because the backend now binds a Unix Domain Socket
> at `~/Library/Application Support/RepoWhisper/backend.sock`, not TCP port 8000.

## Stale UDS socket

**Symptom**: app shows "Backend offline" after a crash.

**Fix**: the backend deletes any stale `backend.sock` on startup
([BackendProcessManager.swift](frontend/RepoWhisper/BackendProcessManager.swift)).
If for some reason that fails, remove it manually:
```bash
rm -f "$HOME/Library/Application Support/RepoWhisper/backend.sock"
```
Then quit and relaunch RepoWhisper.

## "Not Found" Error

**Error**: `{"detail": "Not Found"}`

**Causes**:
1. Wrong endpoint URL
2. Backend not fully started yet
3. Missing trailing slash

**Fix**:
```bash
# Wait a few seconds after starting
sleep 3

# Test health endpoint first
curl http://127.0.0.1:8000/health

# Check available endpoints
curl http://127.0.0.1:8000/docs  # Swagger UI
```

## Backend Won't Start

**Check**:
1. Virtual environment activated?
   ```bash
   cd backend
   source venv/bin/activate  # Should see (venv) in prompt
   ```

2. Dependencies installed?
   ```bash
   pip list | grep fastapi
   ```

3. .env file exists?
   ```bash
   ls backend/.env
   ```

## Common Endpoints

- `GET /health` - Health check (no auth)
- `GET /docs` - API documentation
- `POST /index` - Index repository (requires auth)
- `POST /search` - Search code (requires auth)
- `POST /transcribe` - Transcribe audio (requires auth)
- `POST /advise` - Boss Mode advice (requires auth)

## Quick Test Commands

```bash
# 1. Check if backend is running
curl http://127.0.0.1:8000/health

# 2. View API docs in browser
open http://127.0.0.1:8000/docs

# 3. Check what's on port 8000
lsof -i:8000

# 4. Kill backend
pkill -f "python.*main.py"
```

