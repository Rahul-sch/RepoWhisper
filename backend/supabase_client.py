"""
Supabase Client Integration
Handles database operations for repos and profiles.
"""

from typing import Optional
from datetime import datetime
from functools import lru_cache

from supabase import create_client, Client
from config import get_settings


@lru_cache(maxsize=1)
def get_supabase_client() -> Client:
    """Get cached Supabase client instance."""
    settings = get_settings()
    return create_client(settings.supabase_url, settings.supabase_anon_key)


class RepoService:
    """Service for managing repository records in Supabase."""
    
    def __init__(self):
        self.client = get_supabase_client()
    
    def create_or_update_repo(
        self,
        owner_id: str,
        repo_path: str,
        last_indexed: Optional[datetime] = None
    ) -> dict:
        """
        Create or update a repository record.
        
        Args:
            owner_id: User UUID
            repo_path: Path to the repository
            last_indexed: Timestamp of last indexing
            
        Returns:
            Repository record dict
        """
        if last_indexed is None:
            last_indexed = datetime.utcnow()
        
        # Check if repo exists
        existing = self.client.table("repos").select("*").eq("owner_id", owner_id).eq("repo_path", repo_path).execute()
        
        if existing.data:
            # Update existing
            repo_id = existing.data[0]["id"]
            result = (
                self.client.table("repos")
                .update({
                    "last_indexed": last_indexed.isoformat(),
                    "repo_path": repo_path
                })
                .eq("id", repo_id)
                .execute()
            )
        else:
            # Create new
            result = (
                self.client.table("repos")
                .insert({
                    "owner_id": owner_id,
                    "repo_path": repo_path,
                    "last_indexed": last_indexed.isoformat()
                })
                .execute()
            )
        
        return result.data[0] if result.data else {}
    
    def get_user_repos(self, owner_id: str) -> list[dict]:
        """Get all repositories for a user."""
        result = (
            self.client.table("repos")
            .select("*")
            .eq("owner_id", owner_id)
            .order("last_indexed", desc=True)
            .execute()
        )
        return result.data or []
    
    def delete_repo(self, owner_id: str, repo_id: str) -> bool:
        """Delete a repository record."""
        result = (
            self.client.table("repos")
            .delete()
            .eq("id", repo_id)
            .eq("owner_id", owner_id)
            .execute()
        )
        return len(result.data) > 0 if result.data else False
    
    def get_repo(self, owner_id: str, repo_id: str) -> Optional[dict]:
        """Get a specific repository."""
        result = (
            self.client.table("repos")
            .select("*")
            .eq("id", repo_id)
            .eq("owner_id", owner_id)
            .execute()
        )
        return result.data[0] if result.data else None

