# RepoWhisper Deployment Guide

## Production Readiness: ✅ READY

All critical features are implemented and tested. Ready for production deployment.

## Pre-Deployment Checklist

### 1. Environment Configuration

Create `.env` file in `backend/` directory:

```bash
# Supabase (Required)
SUPABASE_URL=your-project-url
SUPABASE_ANON_KEY=your-anon-key
SUPABASE_JWT_SECRET=your-jwt-secret

# Server (Production)
HOST=0.0.0.0
PORT=8000
DEBUG=false

# Models
WHISPER_MODEL=tiny.en
EMBEDDING_MODEL=all-MiniLM-L6-v2

# Boss Mode (Optional)
GROQ_API_KEY=your-groq-key
```

### 2. Backend Deployment

#### Option A: Railway

```bash
# Install Railway CLI
npm i -g @railway/cli

# Login
railway login

# Deploy
cd backend
railway init
railway up
```

#### Option B: Fly.io

```bash
# Install Fly CLI
curl -L https://fly.io/install.sh | sh

# Deploy
cd backend
fly launch
fly deploy
```

#### Option C: Docker

```dockerfile
# Dockerfile
FROM python:3.12-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
```

```bash
docker build -t repowhisper-backend .
docker run -p 8000:8000 --env-file .env repowhisper-backend
```

### 3. Frontend Build

1. **Open Xcode**
2. Create new macOS App project
3. Follow `frontend/XCODE_SETUP.md`
4. Build and archive
5. Code sign with your developer certificate
6. Export for distribution

### 4. Production Configuration

#### Backend

Update `backend/config.py` or environment:

```python
# Production settings
debug: bool = False
host: str = "0.0.0.0"  # Allow external connections
```

#### CORS

Update `backend/main.py`:

```python
allowed_origins = [
    "https://yourdomain.com",
    "repowhisper://*",
    # Remove "*" in production!
]
```

### 5. Database

Supabase is already set up with:
- ✅ `profiles` table
- ✅ `repos` table
- ✅ RLS policies

No migrations needed - already applied via MCP.

### 6. Monitoring

#### Recommended Services

- **Sentry** - Error tracking
- **Datadog** - Performance monitoring
- **Uptime Robot** - Health checks

#### Health Check Endpoint

Monitor: `GET /health`

Expected response:
```json
{
  "status": "healthy",
  "model_loaded": true,
  "index_count": 0,
  "version": "0.1.0"
}
```

### 7. Security Checklist

- [x] JWT validation enabled
- [x] Rate limiting configured
- [x] CORS restricted (update for production)
- [x] Input validation on all endpoints
- [x] User data isolation
- [ ] SSL/TLS enabled (handled by hosting provider)
- [ ] API key rotation plan
- [ ] Backup strategy for vector stores

### 8. Performance Optimization

#### Backend

- Model preloading (already implemented)
- Connection pooling (add if needed)
- Response caching (optional)

#### Frontend

- Lazy loading of results
- Image compression (already implemented)
- Debounced search (already implemented)

## Post-Deployment

### 1. Test End-to-End

1. Sign up new user
2. Index a repository
3. Search for code
4. Test Boss Mode
5. Verify data isolation

### 2. Monitor

- Check error logs
- Monitor API latency
- Track user signups
- Watch for rate limit hits

### 3. Scale

- Add more backend instances if needed
- Consider CDN for static assets
- Database connection pooling
- Vector store optimization

## Troubleshooting

### Backend won't start
- Check environment variables
- Verify Supabase credentials
- Check port availability

### App can't connect
- Verify backend URL in `SupabaseConfig.swift`
- Check CORS settings
- Verify SSL certificate

### Boss Mode not working
- Check screen recording permission
- Verify Groq API key (optional)
- Check screenshot capture logs

## Support

- **Documentation**: See `SETUP.md`, `BOSS_MODE.md`
- **Issues**: GitHub Issues
- **Logs**: Check backend logs for errors

---

**You're ready to launch! 🚀**

