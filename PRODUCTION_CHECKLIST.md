# RepoWhisper - Production SaaS Readiness Checklist

## ✅ Completed (MVP Foundation)

- [x] Supabase database schema (profiles, repos tables)
- [x] RLS policies for data isolation
- [x] FastAPI backend with JWT auth
- [x] Three indexing modes (manual/guided/full)
- [x] SwiftUI MenuBar app structure
- [x] Audio capture and transcription pipeline
- [x] Vector search with LanceDB
- [x] User-specific vector stores (FIXED)

## 🔴 Critical - Must Fix Before Production

### 1. User Data Isolation ✅ FIXED
- [x] Per-user vector stores (`.repowhisper/{user_id}/`)
- [ ] Add user_id to CodeEmbedding schema for filtering
- [ ] Add metadata filtering in search queries

### 2. Xcode Project Setup
- [ ] Create `.xcodeproj` file
- [ ] Add Supabase Swift SDK via SPM
- [ ] Configure Info.plist with microphone permissions
- [ ] Set up app entitlements
- [ ] Configure app bundle ID and signing

### 3. Backend Supabase Integration
- [ ] Install `supabase-py` client
- [ ] Create repo records in `repos` table on index
- [ ] Update `last_indexed` timestamp
- [ ] List user's repos endpoint
- [ ] Delete repo endpoint

### 4. Security Hardening
- [ ] Restrict CORS to specific origins (not `*`)
- [ ] Add rate limiting (e.g., slowapi)
- [ ] Input validation and sanitization
- [ ] JWT secret from environment (not hardcoded)
- [ ] File path validation (prevent directory traversal)

### 5. Error Handling & Logging
- [ ] Structured logging (e.g., structlog)
- [ ] Error response standardization
- [ ] Try/catch around all endpoints
- [ ] Health check with model status

### 6. Environment Configuration
- [ ] `.env.example` with all required vars
- [ ] Document Supabase JWT secret setup
- [ ] Backend URL configuration
- [ ] Model paths configuration

## 🟡 Important - Should Add Soon

### 7. Frontend Polish
- [ ] Keyboard shortcut handler (⌘⇧R)
- [ ] Show ResultsWindow when results arrive
- [ ] Error toast notifications
- [ ] Loading states everywhere
- [ ] Offline mode detection

### 8. Database Operations
- [ ] Sync repo metadata to Supabase
- [ ] Track indexing progress
- [ ] Store search history
- [ ] User preferences table

### 9. Performance
- [ ] Model preloading on startup
- [ ] Embedding batch size tuning
- [ ] Connection pooling
- [ ] Response caching for health checks

### 10. Testing
- [ ] Unit tests for indexer
- [ ] Integration tests for API
- [ ] E2E tests for Swift app
- [ ] Load testing for search latency

## 🟢 Nice to Have - Future Enhancements

- [ ] Multi-repo support per user
- [ ] Real-time indexing progress
- [ ] Search history and favorites
- [ ] Export search results
- [ ] Team/organization support
- [ ] Usage analytics
- [ ] Deployment automation (Docker, etc.)
- [ ] CI/CD pipeline

## 🚀 Deployment Checklist

- [ ] Backend deployment (Railway, Fly.io, etc.)
- [ ] Environment variables configured
- [ ] Database migrations applied
- [ ] Swift app code signing
- [ ] App Store Connect setup (if distributing)
- [ ] Monitoring and alerting
- [ ] Backup strategy

---

**Current Status**: MVP foundation complete, but **NOT production-ready** without fixing critical items 1-6.

