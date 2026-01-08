"""
RepoWhisper Backend Configuration
Handles environment variables and settings for the application.
"""

import os
from enum import Enum
from functools import lru_cache
from pydantic_settings import BaseSettings


class IndexMode(str, Enum):
    """Indexing mode for repository scanning."""
    MANUAL = "manual"      # User selects specific files
    GUIDED = "guided"      # LLM-guided file selection  
    FULL = "full"          # Index entire repository


class Settings(BaseSettings):
    """Application settings loaded from environment variables."""
    
    # Supabase Configuration
    supabase_url: str = "https://kjpxpppaeydireznlzwe.supabase.co"
    supabase_anon_key: str = ""
    supabase_jwt_secret: str = ""
    
    # Server Configuration
    host: str = "127.0.0.1"
    port: int = 8000
    debug: bool = True
    
    # Model Configuration
    whisper_model: str = "tiny.en"
    embedding_model: str = "all-MiniLM-L6-v2"
    
    # Index Configuration
    default_index_mode: IndexMode = IndexMode.GUIDED
    supported_extensions: list[str] = [
        ".py", ".swift", ".js", ".ts", ".tsx", ".jsx",
        ".go", ".rs", ".java", ".kt", ".cpp", ".c", ".h",
        ".md", ".txt", ".json", ".yaml", ".yml"
    ]
    
    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


@lru_cache
def get_settings() -> Settings:
    """Get cached settings instance."""
    return Settings()

