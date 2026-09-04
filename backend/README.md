# RepoWhisper backend

This FastAPI process is a local sidecar launched by the macOS app. It listens on a Unix-domain socket, validates a random `X-Auth-Token`, indexes only app-approved paths, and persists per-user LanceDB data under the app support directory.

Python 3.12 is required:

```bash
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

The app sets these mandatory runtime variables:

- `REPOWHISPER_SOCKET_PATH`
- `REPOWHISPER_AUTH_TOKEN`
- `REPOWHISPER_ALLOWLIST_FILE`
- `REPOWHISPER_DATA_DIR`

Do not expose this service on TCP for normal use. `/health` is the only unauthenticated route; every other endpoint requires the launch token. The API supports repository indexing and deletion, semantic search, raw PCM and encoded-file transcription, warmup, meeting advice, screenshot normalization, and visible-code explanation.

```bash
PYTHONPATH=backend python3.12 -m unittest discover -s backend/tests -v
```

See [ENV_SETUP.md](ENV_SETUP.md) for optional model and provider settings.
