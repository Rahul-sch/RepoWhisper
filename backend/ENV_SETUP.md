# Environment Setup

Create a `.env` file in the `backend/` directory with the following variables:

```bash
# Supabase Configuration
SUPABASE_URL=https://kjpxpppaeydireznlzwe.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtqcHhwcHBhZXlkaXJlem5sendlIiwicm9sZSI6ImFub24iLCJpYXQOjE3Njc5MDIwNTIsImV4cCI6MjA4MzQ3ODLc8ThKtbqOtvKU2yda_eZv2q91-gUHnMX-laVc
SUPABASE_JWT_SECRET=your-jwt-secret-here

# Server Configuration
HOST=127.0.0.1
PORT=8000
DEBUG=true

# Model Configuration
WHISPER_MODEL=tiny.en
EMBEDDING_MODEL=all-MiniLM-L6-v2

# Index Configuration
DEFAULT_INDEX_MODE=guided
```

## Getting Supabase Credentials

1. Go to https://supabase.com/dashboard
2. Select your project
3. Go to Settings > API
4. Copy:
   - **Project URL** → `SUPABASE_URL`
   - **anon/public key** → `SUPABASE_ANON_KEY`
   - **JWT Secret** → `SUPABASE_JWT_SECRET`

