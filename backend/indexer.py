"""
RepoWhisper Code Indexer
Discovers and chunks code files for vector indexing.
Supports three modes: manual, guided, and full repo scanning.
"""

import os
from pathlib import Path
from typing import Generator
from dataclasses import dataclass
import fnmatch
import re

from config import get_settings, IndexMode


@dataclass
class CodeChunk:
    """Represents a chunk of code for indexing."""
    file_path: str
    content: str
    line_start: int
    line_end: int
    chunk_type: str  # 'file', 'function', 'class', 'block'


def discover_files(
    repo_path: str,
    mode: IndexMode,
    file_paths: list[str] | None = None,
    patterns: list[str] | None = None
) -> list[str]:
    """
    Discover files to index based on the indexing mode.
    
    Args:
        repo_path: Root path of the repository
        mode: Indexing mode (manual, guided, full)
        file_paths: Specific files for manual mode
        patterns: Glob patterns for guided mode
        
    Returns:
        List of absolute file paths to index
    """
    settings = get_settings()
    repo = Path(repo_path).resolve()
    
    if not repo.exists():
        raise ValueError(f"Repository path does not exist: {repo_path}")
    
    if mode == IndexMode.MANUAL:
        return _discover_manual(repo, file_paths or [])
    elif mode == IndexMode.GUIDED:
        return _discover_guided(repo, patterns or ["*.py", "*.swift", "*.ts"])
    else:  # FULL mode
        return _discover_full(repo, settings.supported_extensions)


def _discover_manual(repo: Path, file_paths: list[str]) -> list[str]:
    """Discover files in manual mode - only specified files."""
    discovered = []
    
    for path in file_paths:
        full_path = repo / path if not Path(path).is_absolute() else Path(path)
        if full_path.exists() and full_path.is_file():
            discovered.append(str(full_path.resolve()))
    
    return discovered


def _discover_guided(repo: Path, patterns: list[str]) -> list[str]:
    """Discover files matching glob patterns."""
    discovered = []
    
    for pattern in patterns:
        for file_path in repo.rglob(pattern):
            if _should_index(file_path):
                discovered.append(str(file_path.resolve()))
    
    return list(set(discovered))  # Remove duplicates


def _discover_full(repo: Path, extensions: list[str]) -> list[str]:
    """Discover all files with supported extensions."""
    discovered = []
    
    for ext in extensions:
        pattern = f"*{ext}"
        for file_path in repo.rglob(pattern):
            if _should_index(file_path):
                discovered.append(str(file_path.resolve()))
    
    return discovered


def _should_index(file_path: Path) -> bool:
    """Check if a file should be indexed (skip hidden, vendor, etc.)."""
    skip_patterns = [
        "*/.*",           # Hidden files/folders
        "*/__pycache__/*",
        "*/node_modules/*",
        "*/.git/*",
        "*/venv/*",
        "*/.venv/*",
        "*/build/*",
        "*/dist/*",
        "*/.next/*",
        "*/Pods/*",
        "*/.build/*",
    ]
    
    path_str = str(file_path)
    
    for pattern in skip_patterns:
        if fnmatch.fnmatch(path_str, pattern):
            return False
    
    return file_path.is_file()


def chunk_file(file_path: str, max_chunk_size: int = 1000) -> list[CodeChunk]:
    """
    Split a file into indexable chunks.
    
    Uses simple heuristics to split on function/class boundaries.
    For better results, consider using tree-sitter in production.
    
    Args:
        file_path: Path to the file to chunk
        max_chunk_size: Maximum characters per chunk
        
    Returns:
        List of CodeChunk objects
    """
    try:
        with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
            content = f.read()
    except Exception as e:
        print(f"Error reading {file_path}: {e}")
        return []
    
    if len(content) <= max_chunk_size:
        # Small file - index as single chunk
        return [CodeChunk(
            file_path=file_path,
            content=content,
            line_start=1,
            line_end=content.count('\n') + 1,
            chunk_type='file'
        )]
    
    # Split into logical chunks
    return _split_into_chunks(file_path, content, max_chunk_size)


def _split_into_chunks(
    file_path: str, 
    content: str, 
    max_size: int
) -> list[CodeChunk]:
    """Split content into chunks based on code structure."""
    chunks = []
    lines = content.split('\n')
    
    # Patterns for code boundaries (Python, Swift, JS/TS, etc.)
    boundary_patterns = [
        r'^(def |async def )\w+',      # Python functions
        r'^class \w+',                  # Classes
        r'^(func |@\w+ func )\w+',     # Swift functions
        r'^(function |const \w+ = )',  # JavaScript
        r'^(export |import )',          # Module boundaries
    ]
    
    current_chunk_lines = []
    current_start = 1
    
    for i, line in enumerate(lines, 1):
        # Check if this line is a boundary
        is_boundary = any(
            re.match(pattern, line.strip()) 
            for pattern in boundary_patterns
        )
        
        current_chunk_lines.append(line)
        current_content = '\n'.join(current_chunk_lines)
        
        # Split if we hit max size at a boundary, or forced split at 2x max
        should_split = (
            (is_boundary and len(current_content) >= max_size * 0.7) or
            len(current_content) >= max_size * 2
        )
        
        if should_split and len(current_chunk_lines) > 1:
            # Create chunk from accumulated lines (minus current boundary line)
            chunk_lines = current_chunk_lines[:-1] if is_boundary else current_chunk_lines
            chunk_content = '\n'.join(chunk_lines)
            
            if chunk_content.strip():
                chunks.append(CodeChunk(
                    file_path=file_path,
                    content=chunk_content,
                    line_start=current_start,
                    line_end=current_start + len(chunk_lines) - 1,
                    chunk_type='block'
                ))
            
            # Start new chunk
            current_chunk_lines = [line] if is_boundary else []
            current_start = i
    
    # Don't forget the last chunk
    if current_chunk_lines:
        final_content = '\n'.join(current_chunk_lines)
        if final_content.strip():
            chunks.append(CodeChunk(
                file_path=file_path,
                content=final_content,
                line_start=current_start,
                line_end=current_start + len(current_chunk_lines) - 1,
                chunk_type='block'
            ))
    
    return chunks


def index_repository(
    repo_path: str,
    mode: IndexMode,
    file_paths: list[str] | None = None,
    patterns: list[str] | None = None
) -> Generator[CodeChunk, None, None]:
    """
    Main entry point for indexing a repository.
    
    Yields CodeChunk objects for each chunk discovered.
    
    Args:
        repo_path: Root path of the repository
        mode: Indexing mode
        file_paths: Specific files (manual mode)
        patterns: Glob patterns (guided mode)
        
    Yields:
        CodeChunk objects ready for embedding
    """
    files = discover_files(repo_path, mode, file_paths, patterns)
    
    for file_path in files:
        chunks = chunk_file(file_path)
        for chunk in chunks:
            yield chunk

