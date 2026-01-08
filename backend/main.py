"""
RepoWhisper FastAPI Backend
Main application entry point with all API endpoints.
"""

from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
import uvicorn

from config import get_settings, IndexMode
from auth import get_current_user, get_user_id, get_optional_user


# Initialize FastAPI app
app = FastAPI(
    title="RepoWhisper API",
    description="Real-time voice-to-code search API",
    version="0.1.0"
)

# Configure CORS for Swift app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Allow all for local development
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============ Request/Response Models ============

class IndexRequest(BaseModel):
    """Request model for indexing a repository."""
    mode: IndexMode
    repo_path: str
    file_paths: Optional[list[str]] = None  # For manual mode


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


class SearchResult(BaseModel):
    """A single search result."""
    file_path: str
    chunk: str
    score: float
    line_start: int
    line_end: int


class SearchResponse(BaseModel):
    """Response model for search operation."""
    results: list[SearchResult]
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
    version: str


# ============ API Endpoints ============

@app.get("/health", response_model=HealthResponse)
async def health_check():
    """Health check endpoint - no auth required."""
    return HealthResponse(
        status="healthy",
        model_loaded=False,  # Will be updated when models load
        version="0.1.0"
    )


@app.post("/index", response_model=IndexResponse)
async def index_repository(
    request: IndexRequest,
    user_id: str = Depends(get_user_id)
):
    """
    Index a repository for vector search.
    Requires authentication.
    """
    # TODO: Implement actual indexing logic
    return IndexResponse(
        success=True,
        files_indexed=0,
        chunks_created=0,
        message=f"Indexing {request.repo_path} in {request.mode} mode (stub)"
    )


@app.post("/search", response_model=SearchResponse)
async def search_code(
    request: SearchRequest,
    user_id: str = Depends(get_user_id)
):
    """
    Search indexed code using semantic vector search.
    Requires authentication.
    """
    # TODO: Implement actual search logic
    return SearchResponse(
        results=[],
        query=request.query,
        latency_ms=0.0
    )


@app.post("/transcribe", response_model=TranscribeResponse)
async def transcribe_audio(
    user: Optional[dict] = Depends(get_optional_user)
):
    """
    Transcribe audio to text using Faster-Whisper.
    Optional authentication for local development.
    """
    # TODO: Implement actual transcription logic
    return TranscribeResponse(
        text="",
        confidence=0.0,
        latency_ms=0.0
    )


# ============ Entry Point ============

if __name__ == "__main__":
    settings = get_settings()
    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug
    )

