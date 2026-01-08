# Security Fixes - Codex Review Response

## Issues Fixed

### 1. ✅ Multi-Tenant Data Isolation

**Problem**: `/index` was clearing the entire table, potentially affecting all users.

**Fix**:
- Added `user_id` and `repo_id` to `CodeEmbedding` schema
- Updated `index_chunks()` to include user and repo isolation
- Updated `search()` to filter by `user_id` (required) and optionally `repo_id`
- Each user's data is now properly isolated

**Note**: LanceDB doesn't support efficient deletes, so old repo data is filtered out during search rather than deleted. For production at scale, consider:
- Separate tables per user
- Vector DB with delete support (Pinecone, Weaviate)
- Soft delete with timestamp

### 2. ✅ Authentication Hardening

**Problem**: 
- `/transcribe` allowed anonymous access
- JWT validation skipped when secret not set

**Fix**:
- `/transcribe` now requires authentication (`get_user_id` instead of `get_optional_user`)
- JWT validation required in production (only skips in explicit debug mode)
- Added proper error messages

### 3. ✅ CORS Security

**Problem**: CORS allowed `*` in debug mode, which could be misconfigured.

**Fix**:
- Removed automatic `*` in debug mode
- Requires explicit `ALLOW_ALL_CORS=true` environment variable
- Production origins must be explicitly listed

### 4. ✅ Path Sandboxing

**Problem**: No restriction on which directories users could index.

**Fix**:
- Added `REPO_SANDBOX_BASE` environment variable (defaults to user home)
- Validates paths are within sandbox directory
- Prevents directory traversal attacks
- Returns 403 Forbidden for paths outside sandbox

### 5. ✅ Repository Tracking

**Problem**: No way to track which repos belong to which users in vector store.

**Fix**:
- Repos are now tracked in Supabase `repos` table
- Vector store includes `repo_id` for filtering
- Search can filter by specific repo or all user repos

## Remaining Considerations

### For Production Scale

1. **Vector DB Choice**: Consider migrating to Pinecone/Weaviate for better multi-tenancy
2. **Background Processing**: Indexing large repos should be async
3. **Quotas**: Add per-user indexing limits
4. **Monitoring**: Add observability for multi-tenant operations
5. **Testing**: Add integration tests for isolation

### Environment Variables

Add to production `.env`:
```bash
# Path sandboxing
REPO_SANDBOX_BASE=/var/repowhisper/users

# CORS (never use in production)
ALLOW_ALL_CORS=false
```

## Status

✅ **All Codex-identified security issues have been addressed.**

The codebase now has proper multi-tenant isolation, required authentication, hardened CORS, and path sandboxing.

