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
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

from config import get_settings, IndexMode
from auth import get_current_user, get_user_id, get_optional_user
from indexer import index_repository as index_repo, CodeChunk
from search import get_vector_store, SearchResult as VectorSearchResult
from transcribe import transcribe_audio as whisper_transcribe, get_whisper_model
from supabase_client import RepoService
from logger import setup_logging, get_logger


# ============ Lifespan Management ============

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifespan - preload models."""
    settings = get_settings()
    setup_logging(settings.debug)
    logger = get_logger()
    
    logger.info("starting_backend", version="0.1.0")
    
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

# Configure CORS - restrict to localhost and specific origins
settings = get_settings()
allowed_origins = [
    "http://localhost:8000",
    "http://127.0.0.1:8000",
    "repowhisper://*",  # Swift app custom URL scheme
]

# In production, add your actual frontend domain
if settings.debug:
    allowed_origins.append("*")  # Allow all in debug mode

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

@app.get("/health", response_model=HealthResponse)
@limiter.limit("100/minute")
async def health_check(request: Request):
    """Health check endpoint - no auth required."""
    try:
        # Check if models are loaded
        model_loaded = True
        try:
            get_whisper_model()
        except:
            model_loaded = False
        
        return HealthResponse(
            status="healthy",
            model_loaded=model_loaded,
            index_count=0,  # User-specific, can't show global count
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
        # Validate repo path (prevent directory traversal)
        if ".." in index_request.repo_path or index_request.repo_path.startswith("/"):
            raise HTTPException(status_code=400, detail="Invalid repository path")
        
        # Get user-specific vector store
        store = get_vector_store(user_id)
        
        # Clear existing index for this repo
        store.clear()
        
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
        
        # Index chunks
        indexed_count = store.index_chunks(chunks)
        
        # Count unique files
        unique_files = len(set(c.file_path for c in chunks))
        
        # Update Supabase repo record
        repo_service = RepoService()
        repo_service.create_or_update_repo(
            owner_id=user_id,
            repo_path=index_request.repo_path
        )
        
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
    user: Optional[dict] = Depends(get_optional_user)
):
    """
    Transcribe audio to text using Faster-Whisper.
    Accepts raw PCM audio bytes (16kHz, mono, 16-bit).
    Optional authentication for local development.
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
        repo_service = RepoService()
        repos = repo_service.get_user_repos(user_id)
        logger.info("repos_listed", user_id=user_id, count=len(repos))
        return repos
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
        repo_service = RepoService()
        success = repo_service.delete_repo(user_id, repo_id)
        if not success:
            raise HTTPException(status_code=404, detail="Repository not found")
        logger.info("repo_deleted", user_id=user_id, repo_id=repo_id)
        return {"success": True, "message": "Repository deleted"}
    except HTTPException:
        raise
    except Exception as e:
        logger.error("delete_repo_failed", error=str(e), exc_info=True)
        raise HTTPException(status_code=500, detail="Failed to delete repository")


# ============ Entry Point ============

if __name__ == "__main__":
    settings = get_settings()
    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug
    )
