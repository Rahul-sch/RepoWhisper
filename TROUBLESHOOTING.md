# Troubleshooting

## Backend does not start

- Add at least one repository; startup intentionally waits for an approved path.
- For source builds, install `backend/requirements.txt` with Python 3.12.
- For Release builds, run `build_binaries.sh` before archiving.
- Inspect the app console for the backend log and Unix socket paths.

## No transcription

- Enable RepoWhisper under System Settings → Privacy & Security → Microphone.
- Confirm Faster-Whisper is installed or included in the packaged backend.
- Allow model downloads on first launch, or run `prebake_models.sh` before packaging.

## Explain Visible or Boss Mode cannot capture

Enable RepoWhisper under System Settings → Privacy & Security → Screen Recording, then relaunch the app.

## Search returns no results

Open the main window, select an approved repository, and index it. Re-index after substantial source changes. Removed repository permissions take effect immediately and intentionally block search/index access.

## Build diagnostics

```bash
./test.sh
cd frontend && swift build
```

The sidecar is not a normal TCP web server. Test it through the app or use `test_backend.sh` with the socket and launch token supplied by a running app instance.
