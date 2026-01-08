"""
RepoWhisper JWT Authentication Middleware
Validates Supabase Auth tokens on every request.
"""

from fastapi import Request, HTTPException, Depends
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from functools import lru_cache
from typing import Optional
import httpx

from config import get_settings


# Security scheme for Swagger UI
security = HTTPBearer(auto_error=False)


class JWTValidator:
    """Validates Supabase JWT tokens."""
    
    def __init__(self):
        self.settings = get_settings()
        self._jwks_cache: Optional[dict] = None
    
    @lru_cache(maxsize=1)
    def _get_jwks_url(self) -> str:
        """Get the JWKS URL for the Supabase project."""
        return f"{self.settings.supabase_url}/auth/v1/.well-known/jwks.json"
    
    async def _fetch_jwks(self) -> dict:
        """Fetch JWKS from Supabase (cached)."""
        if self._jwks_cache:
            return self._jwks_cache
        
        async with httpx.AsyncClient() as client:
            response = await client.get(self._get_jwks_url())
            response.raise_for_status()
            self._jwks_cache = response.json()
            return self._jwks_cache
    
    def decode_token(self, token: str) -> dict:
        """
        Decode and validate a Supabase JWT token.
        
        Args:
            token: The JWT token string
            
        Returns:
            The decoded token payload
            
        Raises:
            HTTPException: If token is invalid or expired
        """
        try:
            # Require JWT secret in production
            if not self.settings.supabase_jwt_secret:
                # Only allow unverified tokens in explicit debug mode
                if not self.settings.debug:
                    raise HTTPException(
                        status_code=401,
                        detail="JWT secret not configured. Authentication required.",
                        headers={"WWW-Authenticate": "Bearer"}
                    )
                # Decode without verification (only for development)
                payload = jwt.decode(
                    token,
                    options={"verify_signature": False}
                )
                return payload
            
            # Validate with JWT secret
            payload = jwt.decode(
                token,
                self.settings.supabase_jwt_secret,
                algorithms=["HS256"],
                audience="authenticated",
                options={"verify_aud": False}  # Supabase doesn't always set audience
            )
            return payload
        except JWTError as e:
            raise HTTPException(
                status_code=401,
                detail=f"Invalid authentication token: {str(e)}",
                headers={"WWW-Authenticate": "Bearer"}
            )


# Singleton validator instance
_validator = JWTValidator()


async def get_current_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)
) -> dict:
    """
    Dependency to get the current authenticated user.
    
    Args:
        credentials: The HTTP Bearer credentials
        
    Returns:
        The decoded user payload from the JWT
        
    Raises:
        HTTPException: If not authenticated or token invalid
    """
    if not credentials:
        raise HTTPException(
            status_code=401,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"}
        )
    
    return _validator.decode_token(credentials.credentials)


async def get_user_id(user: dict = Depends(get_current_user)) -> str:
    """
    Dependency to get just the user ID from the token.
    
    Args:
        user: The decoded user payload
        
    Returns:
        The user's UUID string
    """
    return user.get("sub")


# Optional auth - returns None if not authenticated
async def get_optional_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Depends(security)
) -> Optional[dict]:
    """
    Dependency for optional authentication.
    Returns None if no token provided, validates if present.
    """
    if not credentials:
        return None
    
    try:
        return _validator.decode_token(credentials.credentials)
    except HTTPException:
        return None

