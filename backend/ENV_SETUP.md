# Environment Setup

Create a `.env` file in the `backend/` directory with the following variables:

```bash
# Supabase Configuration
SUPABASE_URL=https://kjpxpppaeydireznlzwe.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtqcHhwcHBhZXlkaXJlem5sendlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njc5MDIwNTIsImV4cCI6MjA4MzQ3ODA1Mn0.YAHTxLc8ThKtbqOtvKU2yda_eZv2q91-gUHnMX-laVc
SUPABASE_JWT_SECRET=e77ca237-27bf-4863-924f-22a13d135d40

# Server Configuration
HOST=127.0.0.1
PORT=8000
DEBUG=true

# Model Configuration
WHISPER_MODEL=tiny.en
EMBEDDING_MODEL=all-MiniLM-L6-v2

# Index Configuration
DEFAULT_INDEX_MODE=guided

# Boss Mode - Groq API (optional, for AI talking points)
GROQ_API_KEY=your-groq-api-key-here
```

## Getting Supabase Credentials

1. Go to https://supabase.com/dashboard
2. Select your project
3. Go to Settings > API
4. Copy:
   - **Project URL** → `SUPABASE_URL`
   - **anon/public key** → `SUPABASE_ANON_KEY`
   - **JWT Secret** → `SUPABASE_JWT_SECRET`

## Getting Groq API Key (Optional - for Boss Mode)

1. Go to https://console.groq.com
2. Sign up or log in
3. Navigate to API Keys section
4. Create a new API key
5. Copy the key → `GROQ_API_KEY`

**Note:** If not set, Boss Mode will use rule-based fallback talking points.

