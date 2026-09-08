# Security model and verification

RepoWhisper processes approved repository files through a local Unix socket.
The native app supplies a per-install authentication token. Folder approval is
an access boundary, not an operating-system sandbox: the backend process runs
with the user's privileges.

## External providers

An API key alone does not enable the advisor. To intentionally send transcript,
code snippets, and optional screenshots to Groq, set both

- `REPOWHISPER_ADVISOR_PROVIDER=groq`
- `GROQ_API_KEY`

Code explanation uses its separate explicit
`REPOWHISPER_EXPLANATION_PROVIDER=groq` setting. Provider context leaves the Mac
when configured. Model downloads also require network access. Runtime settings
come from the process environment; a repository's `.env` is not automatically
loaded. Do not put real credentials into tracked configuration files.

## September 8, 2026 hardening

- Search results are checked against current folder approval before release.
- API errors omit submitted values and internal exception messages.
- Authentication rejects duplicate and oversized headers; browser-origin
  requests are rejected. Responses prohibit caching.
- Request bodies have route-specific byte budgets enforced before parsing,
  including streamed bodies and mismatched Content-Length declarations.
- Screenshot handling accepts only JPEG/PNG, limits decoded pixels to 16 million,
  and reduces both dimensions to at most 1024 pixels.
- Source chunking bounds reads and rejects binary content, terminal symlinks,
  and special files. Allowlist parsing rejects relative and malformed roots.
- Swift transport rejects ambiguous framing, negative content lengths, invalid
  statuses, and signed or overflowing chunks; received data is capped at 64 MiB.
- Application logs no longer print search queries or transcribed text.
- Provider HTTP calls have finite timeouts and no automatic retries.

The installed runtime was scanned with pip-audit 2.10.1. The initial scan found
17 advisory entries in four packages. After upgrading FastAPI/Starlette,
PyArrow, python-dotenv, sentence-transformers, and Transformers, the scan reported
no known vulnerabilities. This result is time-specific and does not establish
that every dependency is vulnerability-free.

## Reproducing checks

Run `PYTHON_BIN=/path/to/runtime/python ./test.sh` for backend tests, Swift tests,
source secret checks, and the Xcode Debug build. Scan the production environment
with `pip-audit --path /path/to/runtime/lib/python3.12/site-packages`.
Rebuild the frozen sidecar with `build_binaries.sh` after backend or dependency
changes; an older packaged executable does not contain source fixes.

## Remaining boundaries

This review does not establish protection against a hostile process running as
the same macOS user. Such a process may read user-owned credentials, manipulate
ancestor directories between path checks and file opens, or inspect process
memory. Same-user filesystem races are not fully eliminated by terminal
O_NOFOLLOW checks. Model provenance and downloaded weights are not cryptographically
pinned by this pass. Signing, notarization, and a separate penetration test are
outside the verification performed here.
