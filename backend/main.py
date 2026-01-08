"""
RepoWhisper FastAPI Backend
Main application entry point with all API endpoints.
"""

from fastapi import FastAPI, Depends, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
from contextlib import asynccontextmanager
import uvicorn

from config import get_settings, IndexMode
from auth import get_current_user, get_user_id, get_optional_user
from indexer import index_repository as index_repo, CodeChunk
from search import get_vector_store, SearchResult as VectorSearchResult
from transcribe import transcribe_audio as whisper_transcribe, get_whisper_model


# ============ Lifespan Management ============

@asynccontextmanager
async def lifespan(app: FastAPI):
    """Manage application lifespan - preload models."""
    print("🚀 Starting RepoWhisper backend...")
    
    # Preload models for faster first request
    settings = get_settings()
    if settings.debug:
        print("⏳ Preloading Whisper model...")
        get_whisper_model()
        print("✅ Whisper model loaded")
    
    yield
    
    print("👋 Shutting down RepoWhisper backend...")


# Initialize FastAPI app
app = FastAPI(
    title="RepoWhisper API",
    description="Real-time voice-to-code search API",
    version="0.1.0",
    lifespan=lifespan
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
async def health_check():
    """Health check endpoint - no auth required."""
    store = get_vector_store()
    return HealthResponse(
        status="healthy",
        model_loaded=True,
        index_count=store.count(),
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
    try:
        store = get_vector_store()
        
        # Clear existing index for this repo (simple approach)
        store.clear()
        
        # Collect chunks
        chunks = list(index_repo(
            repo_path=request.repo_path,
            mode=request.mode,
            file_paths=request.file_paths,
            patterns=request.patterns
        ))
        
        if not chunks:
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
        
        return IndexResponse(
            success=True,
            files_indexed=unique_files,
            chunks_created=indexed_count,
            message=f"Successfully indexed {unique_files} files ({indexed_count} chunks)"
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/search", response_model=SearchResponse)
async def search_code(
    request: SearchRequest,
    user_id: str = Depends(get_user_id)
):
    """
    Search indexed code using semantic vector search.
    Requires authentication.
    """
    try:
        store = get_vector_store()
        results, latency_ms = store.search(request.query, request.top_k)
        
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
            query=request.query,
            latency_ms=latency_ms
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.post("/transcribe", response_model=TranscribeResponse)
async def transcribe_audio_endpoint(
    request: Request,
    user: Optional[dict] = Depends(get_optional_user)
):
    """
    Transcribe audio to text using Faster-Whisper.
    Accepts raw PCM audio bytes (16kHz, mono, 16-bit).
    Optional authentication for local development.
    """
    try:
        # Read raw audio bytes from request body
        audio_data = await request.body()
        
        if not audio_data:
            return TranscribeResponse(
                text="",
                confidence=0.0,
                latency_ms=0.0
            )
        
        # Transcribe
        result = whisper_transcribe(audio_data)
        
        return TranscribeResponse(
            text=result.text,
            confidence=result.confidence,
            latency_ms=result.latency_ms
        )
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


# ============ Entry Point ============

if __name__ == "__main__":
    settings = get_settings()
    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug
    )
