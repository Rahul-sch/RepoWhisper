"""
RepoWhisper FastAPI Backend
Main application entry point with all API endpoints.
"""

from fastapi import FastAPI, Depends, HTTPException, Request, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ValidationError
from typing import Optional
from contextlib import asynccontextmanager
import uvicorn
import os
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from config import get_settings, IndexMode
from auth import get_current_user, get_user_id, get_optional_user
from indexer import index_repository as index_repo, CodeChunk
from search import get_vector_store, SearchResult as VectorSearchResult
from transcribe import transcribe_audio as whisper_transcribe, get_whisper_model
from logger import setup_logging, get_logger
from advise import get_advisor, AdvisorContext, process_screenshot
from path_validator import init_path_validator, get_path_validator
import uuid


# ============ Lifespan Management ============

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifespan - preload models and init security."""
    settings = get_settings()
    setup_logging(settings.debug)
    logger = get_logger()

    logger.info("starting_backend", version="0.1.0")

    # Initialize path validator (FAIL-CLOSED)
    allowlist_file = os.getenv("REPOWHISPER_ALLOWLIST_FILE")
    if not allowlist_file:
        raise RuntimeError(
            "REPOWHISPER_ALLOWLIST_FILE environment variable not set. "
            "Cannot start without allowlist."
        )

    try:
        init_path_validator(allowlist_file)
        logger.info("path_validator_initialized", allowlist_file=allowlist_file)
    except (FileNotFoundError, ValueError) as e:
        logger.error("path_validator_init_failed", error=str(e))
        raise RuntimeError(f"Failed to initialize path validator: {e}")

    # Preload models for faster first request
    if settings.debug:
        logger.info("preloading_models")
        get_whisper_model()
        logger.info("models_loaded")

    yield

    logger.info("shutting_down_backend")


# Initialize FastAPI app
app = FastAPI(
    title="RepoWhisper API",
    description="Real-time voice-to-code search API",
    version="0.1.0",
    lifespan=lifespan
)

# Rate limiting
limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# Auth Token Middleware (validates X-Auth-Token on every request)
@app.middleware("http")
async def auth_token_middleware(request: Request, call_next):
    """Validate X-Auth-Token header on all requests (except /health)."""
    # Allow /health without auth for monitoring
    if request.url.path == "/health":
        return await call_next(request)

    # Check X-Auth-Token header
    token = request.headers.get("X-Auth-Token")
    expected_token = getattr(app.state, "auth_token", None)

    if not token or not expected_token or token != expected_token:
        return JSONResponse(
            status_code=401,
            content={"detail": "Unauthorized: Invalid or missing X-Auth-Token"}
        )

    return await call_next(request)

# Configure CORS - restrict to specific origins only
settings = get_settings()
allowed_origins = [
    "http://localhost:8000",
    "http://127.0.0.1:8000",
    "repowhisper://*",  # Swift app custom URL scheme
]

# In production, NEVER allow all origins
# Add your actual frontend domain here:
# allowed_origins.append("https://yourdomain.com")

# Only allow * in debug mode AND if explicitly enabled
if settings.debug and os.getenv("ALLOW_ALL_CORS", "false").lower() == "true":
    allowed_origins.append("*")  # Only if explicitly enabled

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["*"],
)

# Global error handler
@app.exception_handler(Exception)
async def global_exception_handler(request: Request, exc: Exception):
    logger = get_logger()
    logger.error("unhandled_exception", error=str(exc), path=request.url.path)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Internal server error", "error": str(exc) if settings.debug else "An error occurred"}
    )

@app.exception_handler(ValidationError)
async def validation_exception_handler(request: Request, exc: ValidationError):
    return JSONResponse(
        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
        content={"detail": exc.errors()}
    )


# ============ Request/Response Models ============

class IndexRequest(BaseModel):
    """Request model for indexing a repository."""
    mode: IndexMode
    repo_path: str
    file_paths: Optional[list[str]] = None  # For manual mode
    patterns: Optional[list[str]] = None    # For guided mode


class IndexResponse(BaseModel):
    """Response model for index operation."""
    success: bool
    files_indexed: int
    chunks_created: int
    message: str


class SearchRequest(BaseModel):
    """Request model for searching the index."""
    query: str
    top_k: int = 5
    repo_id: Optional[str] = None


class SearchResultItem(BaseModel):
    """A single search result."""
    file_path: str
    chunk: str
    score: float
    line_start: int
    line_end: int


class SearchResponse(BaseModel):
    """Response model for search operation."""
    results: list[SearchResultItem]
    query: str
    latency_ms: float


class TranscribeResponse(BaseModel):
    """Response model for transcription."""
    text: str
    confidence: float
    latency_ms: float


class HealthResponse(BaseModel):
    """Response model for health check."""
    status: str
    model_loaded: bool
    index_count: int
    version: str


# ============ API Endpoints ============

@app.get("/")
async def root():
    """Root endpoint - redirects to API docs."""
    from fastapi.responses import RedirectResponse
    return RedirectResponse(url="/docs")


@app.get("/health", response_model=HealthResponse)
@limiter.limit("100/minute")
async def health_check(request: Request):
    """Health check endpoint - no auth required."""
    try:
        # Check if models are loaded
        model_loaded = get_whisper_model() is not None

        # Get index count from default local store
        index_count = 0
        try:
            # Use default local store path (no user_id for local-first)
            store = get_vector_store(user_id="local", db_path=".repowhisper/local")
            index_count = store.count()
        except Exception as count_error:
            # If count fails, return 0 (store might not exist yet)
            logger = get_logger()
            logger.debug("index_count_failed", error=str(count_error))

        return HealthResponse(
            status="healthy",
            model_loaded=model_loaded,
            index_count=index_count,
            version="0.1.0"
        )
    except Exception as e:
        logger = get_logger()
        logger.error("health_check_failed", error=str(e))
        return HealthResponse(
            status="unhealthy",
            model_loaded=False,
            index_count=0,
            version="0.1.0"
        )


@app.post("/index", response_model=IndexResponse)
@limiter.limit("10/minute")
async def index_repository(
    request: Request,
    index_request: IndexRequest,
    user_id: str = Depends(get_user_id)
):
    """
    Index a repository for vector search.
    Requires authentication.
    Rate limited: 10 requests per minute.
    """
    logger = get_logger()
    logger.info("indexing_repository", user_id=user_id, mode=index_request.mode.value, repo_path=index_request.repo_path)
    
    try:
        # Validate repo path
        repo_path_normalized = index_request.repo_path.strip()
        if not repo_path_normalized:
            raise HTTPException(status_code=400, detail="Repository path cannot be empty")

        # Validate against allowlist (FAIL-CLOSED)
        validator = get_path_validator()
        try:
            abs_path = validator.validate_path(repo_path_normalized)
        except PermissionError as e:
            raise HTTPException(status_code=403, detail=str(e))
        
        # Validate path exists and is a directory
        if not os.path.exists(abs_path):
            raise HTTPException(status_code=400, detail="Repository path does not exist")
        
        if not os.path.isdir(abs_path):
            raise HTTPException(status_code=400, detail="Repository path must be a directory")
        
        # Use absolute path for indexing
        repo_path_normalized = abs_path

        # Validate file_paths if in manual mode
        if index_request.file_paths:
            try:
                # Validate each file path against allowlist
                validated_file_paths = validator.validate_paths(index_request.file_paths)
                # Replace with validated paths
                index_request.file_paths = validated_file_paths
            except PermissionError as e:
                raise HTTPException(status_code=403, detail=str(e))

        # Generate a deterministic repo_id from user_id and repo_path
        repo_id = str(uuid.uuid5(uuid.NAMESPACE_DNS, f"{user_id}:{index_request.repo_path}"))

        # Get user-specific vector store
        store = get_vector_store(user_id)
        
        # Note: clear_repo is a no-op - old data will be filtered out during search
        # Re-indexing will add new data, and search filters by repo_id
        store.clear_repo(user_id, repo_id)
        
        # Collect chunks
        chunks = list(index_repo(
            repo_path=index_request.repo_path,
            mode=index_request.mode,
            file_paths=index_request.file_paths,
            patterns=index_request.patterns
        ))
        
        if not chunks:
            logger.warning("no_files_found", repo_path=index_request.repo_path)
            return IndexResponse(
                success=True,
                files_indexed=0,
                chunks_created=0,
                message="No files found to index"
            )
        
        # Index chunks with user and repo isolation
        indexed_count = store.index_chunks(chunks, user_id, repo_id)
        
        # Count unique files
        unique_files = len(set(c.file_path for c in chunks))
        
        logger.info("indexing_complete", files=unique_files, chunks=indexed_count)
        
        return IndexResponse(
            success=True,
            files_indexed=unique_files,
            chunks_created=indexed_count,
            message=f"Successfully indexed {unique_files} files ({indexed_count} chunks)"
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error("indexing_failed", error=str(e), exc_info=True)
        raise HTTPException(status_code=500, detail="Indexing failed. Please check the repository path and try again.")


@app.post("/search", response_model=SearchResponse)
@limiter.limit("60/minute")
async def search_code(
    request: Request,
    search_request: SearchRequest,
    user_id: str = Depends(get_user_id)
):
    """
    Search indexed code using semantic vector search.
    Requires authentication.
    Rate limited: 60 requests per minute.
    """
    logger = get_logger()
    
    try:
        # Validate query
        if not search_request.query or not search_request.query.strip():
            raise HTTPException(status_code=400, detail="Query cannot be empty")
        
        if len(search_request.query) > 500:
            raise HTTPException(status_code=400, detail="Query too long (max 500 characters)")
        
        # Get user-specific vector store
        store = get_vector_store(user_id)
        results, latency_ms = store.search(search_request.query, search_request.top_k)
        
        logger.info("search_complete", query_length=len(search_request.query), results_count=len(results), latency_ms=latency_ms)
        
        return SearchResponse(
            results=[
                SearchResultItem(
                    file_path=r.file_path,
                    chunk=r.content,
                    score=r.score,
                    line_start=r.line_start,
                    line_end=r.line_end
                )
                for r in results
            ],
            query=search_request.query,
            latency_ms=latency_ms
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error("search_failed", error=str(e), exc_info=True)
        raise HTTPException(status_code=500, detail="Search failed. Please try again.")


@app.post("/transcribe", response_model=TranscribeResponse)
@limiter.limit("120/minute")
async def transcribe_audio_endpoint(
    request: Request,
    user_id: str = Depends(get_user_id)  # Require auth in production
):
    """
    Transcribe audio to text using Faster-Whisper.
    Accepts raw PCM audio bytes (16kHz, mono, 16-bit).
    Requires authentication for production security.
    Rate limited: 120 requests per minute.
    """
    logger = get_logger()
    
    try:
        # Read raw audio bytes from request body
        audio_data = await request.body()
        
        if not audio_data:
            return TranscribeResponse(
                text="",
                confidence=0.0,
                latency_ms=0.0
            )
        
        # Validate audio data size (max 10MB)
        if len(audio_data) > 10 * 1024 * 1024:
            raise HTTPException(status_code=400, detail="Audio data too large (max 10MB)")
        
        # Transcribe
        result = whisper_transcribe(audio_data)
        
        logger.info("transcription_complete", text_length=len(result.text), latency_ms=result.latency_ms)
        
        return TranscribeResponse(
            text=result.text,
            confidence=result.confidence,
            latency_ms=result.latency_ms
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error("transcription_failed", error=str(e), exc_info=True)
        raise HTTPException(status_code=500, detail="Transcription failed. Please try again.")


# ============ Additional Endpoints ============

@app.get("/repos", response_model=list[dict])
@limiter.limit("30/minute")
async def list_repos(
    request: Request,
    user_id: str = Depends(get_user_id)
):
    """List all repositories for the authenticated user."""
    logger = get_logger()
    try:
        # Repos are stored locally in the vector store, not in external DB
        # Return empty list - repos are identified by their indexed data
        logger.info("repos_listed", user_id=user_id, count=0)
        return []
    except Exception as e:
        logger.error("list_repos_failed", error=str(e), exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to list repositories")


@app.delete("/repos/{repo_id}")
@limiter.limit("10/minute")
async def delete_repo(
    request: Request,
    repo_id: str,
    user_id: str = Depends(get_user_id)
):
    """Delete a repository."""
    logger = get_logger()
    try:
        # Clear repo data from vector store
        store = get_vector_store(user_id)
        store.clear_repo(user_id, repo_id)
        logger.info("repo_deleted", user_id=user_id, repo_id=repo_id)
        return {"success": True, "message": "Repository deleted"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("delete_repo_failed", error=str(e), exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to delete repository")


# ============ Boss Mode Endpoints ============

class AdviseRequest(BaseModel):
    """Request model for Boss Mode advisor."""
    transcript: str
    screenshot_base64: Optional[str] = None
    code_snippets: Optional[list[str]] = None
    meeting_context: Optional[str] = None


class AdviseResponse(BaseModel):
    """Response model for advisor."""
    talking_point: str
    confidence: float
    context: str


@app.post("/advise", response_model=AdviseResponse)
@limiter.limit("30/minute")
async def get_advice(
    request: Request,
    advise_request: AdviseRequest,
    user_id: str = Depends(get_user_id)
):
    """
    Boss Mode: Generate talking points from transcript, screenshot, and code.
    Requires authentication.
    Rate limited: 30 requests per minute.
    """
    logger = get_logger()
    
    try:
        # Validate transcript
        if not advise_request.transcript or not advise_request.transcript.strip():
            raise HTTPException(status_code=400, detail="Transcript cannot be empty")
        
        # Build context
        context = AdvisorContext(
            transcript=advise_request.transcript,
            screenshot_base64=advise_request.screenshot_base64,
            code_snippets=advise_request.code_snippets or [],
            meeting_context=advise_request.meeting_context
        )
        
        # Get advisor and generate talking point
        advisor = get_advisor()
        talking_point = advisor.generate_talking_point(context)
        
        logger.info("advice_generated", user_id=user_id, confidence=talking_point.confidence)
        
        return AdviseResponse(
            talking_point=talking_point.text,
            confidence=talking_point.confidence,
            context=talking_point.context
        )
        
    except HTTPException:
        raise
    except Exception as e:
        logger.error("advice_generation_failed", error=str(e), exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to generate advice. Please try again.")


@app.post("/screenshot")
@limiter.limit("60/minute")
async def upload_screenshot(
    request: Request,
    user_id: str = Depends(get_user_id)
):
    """
    Upload and process screenshot for Boss Mode.
    Accepts image bytes (JPEG/PNG).
    Returns base64-encoded processed image.
    """
    logger = get_logger()
    
    try:
        # Read image bytes
        image_data = await request.body()
        
        if not image_data:
            raise HTTPException(status_code=400, detail="Screenshot data cannot be empty")
        
        # Validate size (max 20MB)
        if len(image_data) > 20 * 1024 * 1024:
            raise HTTPException(status_code=400, detail="Screenshot too large (max 20MB)")
        
        # Process screenshot
        screenshot_base64 = process_screenshot(image_data)
        
        logger.info("screenshot_processed", user_id=user_id, size_bytes=len(image_data))
        
        return {
            "success": True,
            "screenshot_base64": screenshot_base64,
            "size_bytes": len(image_data)
        }
        
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
    except HTTPException:
        raise
    except Exception as e:
        logger.error("screenshot_processing_failed", error=str(e), exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to process screenshot.")


# ============ Entry Point ============

if __name__ == "__main__":
    import stat
    import socket as sock_module

    settings = get_settings()
    logger = get_logger()

    # Check for required environment variables
    socket_path = os.getenv("REPOWHISPER_SOCKET_PATH")
    auth_token = os.getenv("REPOWHISPER_AUTH_TOKEN")

    if not socket_path:
        logger.error("REPOWHISPER_SOCKET_PATH not set")
        raise RuntimeError("REPOWHISPER_SOCKET_PATH environment variable required")

    if not auth_token:
        logger.error("REPOWHISPER_AUTH_TOKEN not set")
        raise RuntimeError("REPOWHISPER_AUTH_TOKEN environment variable required")

    # Remove stale socket if it exists
    if os.path.exists(socket_path):
        try:
            os.unlink(socket_path)
            logger.info("removed_stale_socket", path=socket_path)
        except OSError as e:
            logger.error("failed_to_remove_stale_socket", path=socket_path, error=str(e))
            raise

    # Set restrictive umask before creating socket
    old_umask = os.umask(0o077)

    try:
        # Store auth token in app state for middleware
        app.state.auth_token = auth_token

        logger.info("starting_uds_server", socket_path=socket_path)

        # Run uvicorn with Unix Domain Socket
        config = uvicorn.Config(
            app=app,
            uds=socket_path,
            log_level="info" if settings.debug else "warning"
        )
        server = uvicorn.Server(config)

        # Ensure socket has correct permissions after creation
        def set_socket_permissions():
            if os.path.exists(socket_path):
                os.chmod(socket_path, 0o600)
                logger.info("set_socket_permissions", path=socket_path, mode="0600")

        # Set permissions after socket is bound
        import asyncio
        import signal

        async def serve():
            # Start server
            await server.serve()

        # Handle cleanup on exit
        def cleanup_handler(signum, frame):
            logger.info("received_signal", signal=signum)
            if os.path.exists(socket_path):
                try:
                    os.unlink(socket_path)
                    logger.info("cleaned_up_socket", path=socket_path)
                except OSError:
                    pass
            raise SystemExit(0)

        signal.signal(signal.SIGINT, cleanup_handler)
        signal.signal(signal.SIGTERM, cleanup_handler)

        try:
            asyncio.run(serve())
            # Set permissions after server starts
            set_socket_permissions()
        finally:
            # Cleanup socket on exit
            if os.path.exists(socket_path):
                try:
                    os.unlink(socket_path)
                    logger.info("cleaned_up_socket_on_exit", path=socket_path)
                except OSError:
                    pass
    finally:
        os.umask(old_umask)
