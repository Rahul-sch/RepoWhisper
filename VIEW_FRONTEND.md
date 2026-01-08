# How to View the Frontend 🎨

## One-Click Open! 🚀

**Just double-click this file:**
```
frontend/RepoWhisper.xcodeproj
```

**OR run:**
```bash
cd frontend
open RepoWhisper.xcodeproj
```

**Then press ⌘R to build and run!**

That's it! The project is **already generated** with:
- ✅ All Swift files included
- ✅ Supabase package configured
- ✅ Info.plist with permissions
- ✅ Entitlements configured
- ✅ Everything ready to go

## Configure Permissions (One-Time Setup)

**After opening the project, you need to set up permissions:**

1. **Click "RepoWhisper"** (blue icon) in sidebar
2. **Select "RepoWhisper" target** → **"Signing & Capabilities" tab**
3. **Add "App Sandbox"** capability
4. **Enable:** Outgoing Connections, User Selected File, Microphone, Camera

**📖 Full guide:** See [`frontend/XCODE_PERMISSIONS.md`](frontend/XCODE_PERMISSIONS.md)

## If Project Gets Corrupted

Just regenerate it:
```bash
cd frontend
xcodegen generate
open RepoWhisper.xcodeproj
```

**No manual file dragging needed!** 🎉

## UI Features ✨

### Modern Design Elements

- **Gradient backgrounds** - Purple to blue gradients throughout
- **Glass morphism** - Ultra-thin material effects (macOS native)
- **Smooth animations** - Spring animations on audio levels
- **Card-based layout** - Clean, organized sections
- **Status indicators** - Color-coded connection status
- **Premium buttons** - Gradient-filled icons with shadows

### What You'll See

1. **Menu Bar Icon** - Waveform circle icon in menu bar
2. **Login Screen** - Dark gradient with purple/blue accents
3. **Main Menu** - Clean card-based interface with:
   - Connection status indicator
   - Index mode selector (segmented control)
   - Repository picker with file browser
   - Boss Mode toggle (crown icon)
   - Recording button (large, gradient-filled)
   - Audio level visualization (animated bars)
   - Talking points card (yellow gradient when active)

4. **Results Window** - Floating panel with:
   - Semi-transparent background
   - Code snippets with syntax styling
   - File icons and line numbers
   - Score badges
   - Click to open in editor

### Design Highlights

- **Color Scheme**: Purple/Blue gradients (modern, tech-forward)
- **Typography**: SF Rounded for friendly feel
- **Spacing**: Generous padding, clean hierarchy
- **Shadows**: Subtle depth with soft shadows
- **Animations**: Smooth spring animations
- **Icons**: SF Symbols throughout (native macOS)

## Preview the UI

The UI is designed to look like:
- **Linear/Notion-style** - Clean, modern, professional
- **macOS Big Sur+** - Native glass morphism effects
- **Premium feel** - Gradients, shadows, smooth animations

## Troubleshooting

### "Cannot find type in scope"
- Make sure Supabase package is added
- Clean build: **⌘⇧K**
- Rebuild: **⌘B**

### App crashes on launch
- Check Info.plist has all permissions
- Verify Supabase credentials in `SupabaseConfig.swift`

### Menu bar icon not showing
- Check app is running (look in Activity Monitor)
- Restart app

## Screenshots

Once running, you'll see:
- Beautiful gradient login screen
- Clean menu bar interface
- Floating results window
- Smooth animations throughout

**It looks premium and modern!** 🎨✨

