# Xcode Permissions Setup Guide 🔐

## Quick Setup (2 minutes)

### Step 1: Open Project Settings

1. **Click on "RepoWhisper"** (blue icon) in the left sidebar
2. **Select the "RepoWhisper" target** (under TARGETS)
3. **Click "Signing & Capabilities" tab**

### Step 2: Configure App Sandbox

1. **Click "+ Capability"** button (top left)
2. **Add "App Sandbox"**
3. **Configure these settings:**
   - ✅ **Outgoing Connections (Client)** - Enable
   - ✅ **User Selected File (Read/Write)** - Enable
   - ✅ **Downloads Folder (Read/Write)** - Enable
   - ✅ **Microphone** - Enable
   - ✅ **Camera** - Enable (for screen recording)

### Step 3: Verify Info.plist

1. **Click "Info" tab** (next to Signing & Capabilities)
2. **Verify these keys exist:**
   - `Privacy - Microphone Usage Description` ✅
   - `Privacy - Screen Recording Usage Description` ✅
   - `Privacy - Accessibility Usage Description` ✅
   - `Privacy - Apple Events Usage Description` ✅

   If any are missing, click **"+"** and add them with these values:

   ```
   Privacy - Microphone Usage Description
   Value: RepoWhisper needs microphone access to transcribe your voice commands for code search.

   Privacy - Screen Recording Usage Description
   Value: RepoWhisper needs screen recording access to capture system audio and screenshots for Boss Mode meeting intelligence.

   Privacy - Accessibility Usage Description
   Value: RepoWhisper needs accessibility access to identify the active window for context-aware screenshots.

   Privacy - Apple Events Usage Description
   Value: RepoWhisper needs to control your computer to open files in your editor.
   ```

### Step 4: Verify Entitlements

1. **Still in "Signing & Capabilities" tab**
2. **Check that "RepoWhisper.entitlements"** is listed
3. If missing, click **"+"** → **"Add Entitlements File"** → Select `RepoWhisper/RepoWhisper.entitlements`

### Step 5: Build & Test

1. **Press ⌘B** to build
2. **Press ⌘R** to run
3. **macOS will prompt for permissions** when the app requests them:
   - **Microphone** - Click "Allow"
   - **Screen Recording** - Go to System Settings → Privacy & Security → Screen Recording → Enable RepoWhisper
   - **Accessibility** - Go to System Settings → Privacy & Security → Accessibility → Enable RepoWhisper

## Visual Guide

```
Xcode Project Navigator:
├── RepoWhisper (blue icon) ← Click this
│   ├── TARGETS
│   │   └── RepoWhisper ← Select this
│   │       ├── General
│   │       ├── Signing & Capabilities ← Go here
│   │       │   ├── App Sandbox ← Add this
│   │       │   └── RepoWhisper.entitlements ← Should be here
│   │       └── Info ← Check permissions here
│   └── RepoWhisper/
│       ├── Info.plist ← Permissions descriptions
│       └── RepoWhisper.entitlements ← Capabilities
```

## Troubleshooting

### "Info.plist not found"
- Make sure `Info.plist` is in the project
- Check "Info" tab → "Custom macOS Application Target Properties"
- If missing, drag `RepoWhisper/Info.plist` into Xcode

### "Entitlements file not found"
- In "Signing & Capabilities", click **"+"** → **"Add Entitlements File"**
- Navigate to `RepoWhisper/RepoWhisper.entitlements`
- Select it

### Permissions not working at runtime
1. **Check System Settings:**
   - System Settings → Privacy & Security → Microphone
   - System Settings → Privacy & Security → Screen Recording
   - System Settings → Privacy & Security → Accessibility
2. **Enable RepoWhisper** in each section
3. **Restart the app**

### "Code signing error"
- In "Signing & Capabilities" → **"Signing"** section
- Check **"Automatically manage signing"**
- Select your **Team** (or "None" for local development)

## Quick Checklist ✅

- [ ] App Sandbox capability added
- [ ] Outgoing Connections enabled
- [ ] User Selected File enabled
- [ ] Microphone enabled
- [ ] Camera enabled (for screen recording)
- [ ] Info.plist has all 4 privacy descriptions
- [ ] Entitlements file is linked
- [ ] Build succeeds (⌘B)
- [ ] App runs (⌘R)
- [ ] Permissions granted in System Settings

## That's It! 🎉

Once configured, the app will request permissions automatically when you run it. Just click "Allow" when prompted!

