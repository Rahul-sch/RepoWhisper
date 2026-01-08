# Fix Supabase Email Confirmation Redirect

## Problem
Email confirmation links are redirecting to `localhost:3000` instead of your app.

## Solution: Configure Supabase Redirect URLs

### Step 1: Go to Supabase Dashboard
1. Open https://supabase.com/dashboard
2. Select your project: `kjpxpppaeydireznlzwe`

### Step 2: Configure Email Redirect URLs
1. Go to **Authentication** → **URL Configuration**
2. Under **Redirect URLs**, add:
   ```
   repowhisper://auth-callback
   ```
3. Under **Site URL**, you can set it to:
   ```
   repowhisper://auth-callback
   ```
   (or leave it as default, doesn't matter for native apps)

### Step 3: Disable Email Confirmation (Optional - for easier testing)
1. Go to **Authentication** → **Providers** → **Email**
2. Uncheck **"Enable email confirmations"**
3. Click **Save**

This will let users sign up and immediately use the app without email confirmation.

### Step 4: Rebuild and Test
1. Rebuild the app (⌘B)
2. Run (⌘R)
3. Sign up with email/password
4. If email confirmation is disabled, you'll be signed in immediately
5. If enabled, click the confirmation link and it should open in the app

## Alternative: Use the Confirmation Link Manually

If you already got a confirmation email:
1. Copy the confirmation link from the email
2. Replace `localhost:3000` with `repowhisper://auth-callback` in the URL
3. Open it in your browser (it will ask to open in RepoWhisper app)
4. Or paste it in Terminal: `open "repowhisper://auth-callback?token=YOUR_TOKEN&type=email"`

## Quick Fix: Disable Email Confirmation

**Easiest solution for development:**
1. Supabase Dashboard → Authentication → Providers → Email
2. Uncheck "Enable email confirmations"
3. Save
4. Users can sign up and use the app immediately

