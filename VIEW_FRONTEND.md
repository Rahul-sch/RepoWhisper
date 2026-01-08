# How to View the Frontend 🎨

## Quick Setup (5 minutes)

### Step 1: Open Xcode

1. **Open Xcode** (must be installed from App Store)
2. **File > New > Project**
3. Choose **macOS > App**
4. Product Name: `RepoWhisper`
5. Interface: **SwiftUI**
6. Language: **Swift**
7. Save to: `/Users/rahulbainsla/Desktop/RepoWhisper/frontend/`
8. Click **Create**

### Step 2: Add Files

1. **Delete** the default `ContentView.swift` and `RepoWhisperApp.swift` (if they exist)
2. **Drag** all files from `frontend/RepoWhisper/` folder into Xcode project
   - Make sure "Copy items if needed" is **checked**
   - Add to target: **RepoWhisper**

### Step 3: Add Supabase SDK

1. **File > Add Package Dependencies**
2. URL: `https://github.com/supabase/supabase-swift`
3. Version: `2.0.0` or latest
4. Add to target: **RepoWhisper**

### Step 4: Configure Info.plist

1. Select project in sidebar > **Target: RepoWhisper** > **Info** tab
2. Add these keys (or they're already in the files you dragged):

```
Privacy - Microphone Usage Description
Value: RepoWhisper needs microphone access to transcribe your voice commands for code search.

Privacy - Screen Recording Usage Description  
Value: RepoWhisper needs screen recording access to capture system audio and screenshots for Boss Mode meeting intelligence.

Privacy - Accessibility Usage Description
Value: RepoWhisper needs accessibility access to identify the active window for context-aware screenshots.
```

### Step 5: Build & Run

1. Press **⌘R** or **Product > Run**
2. Grant permissions when prompted
3. **Menu bar icon appears** - click it!

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

