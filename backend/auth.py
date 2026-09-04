"""Local identity dependency for the authenticated Unix-socket backend."""


LOCAL_USER_ID = "local"


async def get_local_user_id() -> str:
    """Return the stable identity behind the per-install sidecar token."""
    return LOCAL_USER_ID
