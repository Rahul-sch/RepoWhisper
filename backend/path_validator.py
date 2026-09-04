"""
Path Validator - Allowlist-based path validation
Enforces fail-closed security: refuses to start if allowlist is missing/empty.
"""

import os
import json
import threading
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

        self.allowlist_file = os.path.abspath(allowlist_file)
        self._lock = threading.RLock()
        self._allowed_paths: List[str] = []
        self._allowlist_mtime_ns = -1
        self._reload(require_nonempty=True)

        if not self._allowed_paths:
            raise ValueError(
                "Allowlist is empty. Please approve at least one repository folder in the app."
            )

        print(f"✅ [VALIDATOR] Loaded {len(self._allowed_paths)} allowed paths")
        for path in self._allowed_paths:
            print(f"  ✓ {path}")

    @property
    def allowed_paths(self) -> List[str]:
        """Return a fresh snapshot of the current on-disk allowlist."""
        self.refresh_if_changed()
        with self._lock:
            return list(self._allowed_paths)

    def _reload(self, require_nonempty: bool = False) -> None:
        with open(self.allowlist_file, "r", encoding="utf-8") as handle:
            decoded = json.load(handle)
        if not isinstance(decoded, list) or not all(isinstance(path, str) for path in decoded):
            raise ValueError("Allowlist must be a JSON array of paths")
        normalized = [os.path.abspath(path) for path in decoded if path.strip()]
        if require_nonempty and not normalized:
            raise ValueError(
                "Allowlist is empty. Please approve at least one repository folder in the app."
            )
        stat_result = os.stat(self.allowlist_file)
        with self._lock:
            self._allowed_paths = normalized
            self._allowlist_mtime_ns = stat_result.st_mtime_ns

    def refresh_if_changed(self) -> None:
        """Reload an atomically replaced allowlist when its mtime changes."""
        try:
            current_mtime = os.stat(self.allowlist_file).st_mtime_ns
        except OSError:
            with self._lock:
                self._allowed_paths = []
                self._allowlist_mtime_ns = -1
            return
        with self._lock:
            if current_mtime == self._allowlist_mtime_ns:
                return
        try:
            self._reload()
        except (OSError, ValueError, json.JSONDecodeError):
            # Fail closed if the file is missing, malformed, or mid-update.
            with self._lock:
                self._allowed_paths = []
                self._allowlist_mtime_ns = current_mtime

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
