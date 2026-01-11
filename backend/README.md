# RepoWhisper Backend

RepoWhisper is a FastAPI backend that pairs real-time audio transcription with semantic code search. It is designed to power a Swift client that lets users speak about their repository, index code into a LanceDB vector store, and then run natural language queries across the indexed chunks.

## Features
- JWT-protected `/index` and `/search` endpoints backed by Supabase Auth.
- Repo discovery with manual, guided, or full scans plus simple code chunking heuristics (`indexer.py`).
- LanceDB vector store with SentenceTransformers embeddings for semantic search (`search.py`).
- Faster-Whisper powered transcription pipeline with optional streaming helper (`transcribe.py`).
- Boss Mode advisor prototype that can summarize transcripts, screenshots, and code snippets using OpenAI (`advise.py`).
- Supabase client helpers for persisting repository metadata (`supabase_client.py`) and structured logging utilities via `structlog` (`logger.py`).

## Requirements
- Python 3.12+
- System packages for PyTorch, Faster-Whisper, and LanceDB (Apple Silicon and x86_64 Linux tested locally).
- Environment variables listed in `ENV_SETUP.md` (Supabase credentials, API host config, and model names).

Install Python dependencies:

```bash
pip install -r requirements.txt
```

## Local Development
1. Create a `.env` file in `backend/` (see `ENV_SETUP.md` for required keys).
2. (Optional) Download/prepare any large models you plan to use (e.g., Whisper weights).
3. Start the API:
   ```bash
   uvicorn main:app --reload
   ```
4. Visit `http://localhost:8000/docs` for interactive Swagger UI.

## API Surface
| Endpoint        | Method | Auth | Description |
|-----------------|--------|------|-------------|
| `/health`       | GET    | No   | Returns backend status and indexed chunk count. |
| `/index`        | POST   | Yes  | Clears the current LanceDB table and indexes the requested repo. |
| `/search`       | POST   | Yes  | Vector search over previously indexed chunks. |
| `/transcribe`   | POST   | Optional | Accepts raw PCM audio bytes and returns Whisper transcription metadata. |

> **Note:** `RepoService` in `supabase_client.py` exposes CRUD helpers for a `repos` table, but the HTTP layer does not currently expose routes for them.

## High-Level Architecture
```
Client (Swift app)
    │
    │ HTTP (JWT auth via Supabase)
    ▼
FastAPI (main.py)
    ├── auth.py          → Supabase token validation
    ├── indexer.py       → Repo discovery & chunking
    ├── search.py        → LanceDB vector store + embeddings
    ├── transcribe.py    → Faster-Whisper transcription
    ├── advise.py        → Optional Boss Mode advisor
    └── supabase_client.py / logger.py utilities
```

## SaaS Readiness Status
This codebase is **not** production/SaaS ready yet. Critical gaps include:
- **Single-tenant indexing:** `/index` unconditionally drops the shared `code_chunks` table, so concurrent users will erase one another's data. Multi-tenant isolation (table per repo/user or row-level filtering) plus Supabase persistence is still todo.
- **Resource management:** Large ML models load synchronously and remain in memory; no autoscaling strategy, background workers, or queueing exists to handle heavy transcription/indexing workloads safely.
- **Security hardening:** CORS allows all origins, repo paths are accepted verbatim from the client (allowing arbitrary server filesystem access), `/transcribe` permits anonymous access, and JWT validation is incomplete when `SUPABASE_JWT_SECRET` is unset. No rate limiting or audit logging is in place.
- **Operational tooling:** No tests, CI, containerization, or observability hooks; structured logging exists but is unused. Deployment, monitoring, and rollout processes must be defined before production use.
- **Data lifecycle/compliance:** There is no storage quota enforcement, retention policy, or encryption at rest for indexed code or uploaded audio—requirements that most SaaS offerings mandate.

Treat the current backend as a functional prototype suitable for local demos. Converting it into a real SaaS would involve addressing the above items along with legal, billing, and support considerations.

## Next Steps
1. Implement multi-tenant LanceDB storage tied to Supabase identities (e.g., table-per-repo or user partition keys).
2. Harden authentication/authorization, add rate limiting, and sandbox repo indexing to approved paths or storage buckets.
3. Introduce automated tests plus CI to keep the ML-heavy components reliable, and containerize the service for predictable deployments.
4. Wire Supabase persistence routes and Boss Mode advisor endpoints if they are part of the product roadmap.
