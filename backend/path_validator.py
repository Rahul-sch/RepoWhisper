"""
Path Validator - Allowlist-based path validation
Enforces fail-closed security: refuses to start if allowlist is missing/empty.
"""

import os
import json
from typing import List, Optional
from pathlib import Path


class PathValidator:
    """Validates file/directory paths against an allowlist."""

    def __init__(self, allowlist_file: str):
        """
        Initialize path validator.

        Args:
            allowlist_file: Path to allowlist.json

        Raises:
            FileNotFoundError: If allowlist file doesn't exist
            ValueError: If allowlist is empty or invalid
        """
        if not os.path.exists(allowlist_file):
            raise FileNotFoundError(
                f"Allowlist file not found: {allowlist_file}. "
                "Please approve at least one repository folder in the app."
            )

        with open(allowlist_file, "r") as f:
            self.allowed_paths: List[str] = json.load(f)

        if not self.allowed_paths:
            raise ValueError(
                "Allowlist is empty. Please approve at least one repository folder in the app."
            )

        # Normalize all paths to absolute
        self.allowed_paths = [os.path.abspath(p) for p in self.allowed_paths]

        print(f"✅ [VALIDATOR] Loaded {len(self.allowed_paths)} allowed paths")
        for path in self.allowed_paths:
            print(f"  ✓ {path}")

    def is_path_allowed(self, path: str) -> bool:
        """
        Check if a path is under any allowed root.

        Args:
            path: Path to check

        Returns:
            True if path is under an allowed root, False otherwise
        """
        abs_path = os.path.abspath(path)

        for allowed_root in self.allowed_paths:
            # Check if path is under this allowed root
            try:
                # Use resolve() to handle symlinks
                abs_path_resolved = Path(abs_path).resolve()
                allowed_root_resolved = Path(allowed_root).resolve()

                # Check if path is under allowed root
                if abs_path_resolved == allowed_root_resolved or allowed_root_resolved in abs_path_resolved.parents:
                    return True
            except (OSError, RuntimeError):
                # Path doesn't exist or can't be resolved
                continue

        return False

    def validate_path(self, path: str) -> str:
        """
        Validate and return normalized path.

        Args:
            path: Path to validate

        Returns:
            Normalized absolute path

        Raises:
            PermissionError: If path is not in allowlist
        """
        if not self.is_path_allowed(path):
            raise PermissionError(
                f"Path not in allowlist: {path}. "
                "Please approve this folder in the app first."
            )

        return os.path.abspath(path)

    def validate_paths(self, paths: List[str]) -> List[str]:
        """
        Validate multiple paths.

        Args:
            paths: List of paths to validate

        Returns:
            List of normalized absolute paths

        Raises:
            PermissionError: If any path is not in allowlist
        """
        return [self.validate_path(p) for p in paths]


# Global validator instance
_validator: Optional[PathValidator] = None


def init_path_validator(allowlist_file: str) -> PathValidator:
    """
    Initialize the global path validator.
    Must be called on app startup.

    Args:
        allowlist_file: Path to allowlist.json

    Returns:
        Initialized PathValidator

    Raises:
        FileNotFoundError: If allowlist file doesn't exist
        ValueError: If allowlist is empty
    """
    global _validator
    _validator = PathValidator(allowlist_file)
    return _validator


def get_path_validator() -> PathValidator:
    """
    Get the global path validator.

    Returns:
        PathValidator instance

    Raises:
        RuntimeError: If validator not initialized
    """
    if _validator is None:
        raise RuntimeError(
            "Path validator not initialized. Call init_path_validator() first."
        )
    return _validator
