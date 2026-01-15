# RepoWhisper Ship Checklist

Complete guide for building, signing, and distributing RepoWhisper as a production macOS application.

## Prerequisites

- [ ] macOS 14.0+ (for development)
- [ ] Xcode 15.0+ installed
- [ ] Apple Developer account (for signing and notarization)
- [ ] Python 3.11+ (for backend binary compilation)
- [ ] Valid Developer ID Application certificate
- [ ] Valid Developer ID Installer certificate

## Phase 1: Backend Preparation

### 1.1 Create Standalone Backend Binaries

```bash
cd backend

# Install PyInstaller
pip install pyinstaller

# Build for ARM64 (Apple Silicon)
arch -arm64 pyinstaller \
  --name repowhisper-backend-arm64 \
  --onefile \
  --clean \
  --add-data "config.py:." \
  main.py

# Build for x86_64 (Intel)
arch -x86_64 pyinstaller \
  --name repowhisper-backend-x86_64 \
  --onefile \
  --clean \
  --add-data "config.py:." \
  main.py
```

### 1.2 Verify Backend Binaries

```bash
# Test ARM64 binary
./dist/repowhisper-backend-arm64 --version

# Test x86_64 binary (on Intel Mac or Rosetta)
./dist/repowhisper-backend-x86_64 --version
```

### 1.3 Copy Binaries to Xcode Project

```bash
cp dist/repowhisper-backend-arm64 ../frontend/RepoWhisper/Resources/
cp dist/repowhisper-backend-x86_64 ../frontend/RepoWhisper/Resources/
```

- [ ] Backend binaries built successfully
- [ ] Binaries copied to Resources folder
- [ ] Added to Xcode project (Copy Bundle Resources phase)

## Phase 2: Frontend Build

### 2.1 Update Version Numbers

Edit `frontend/RepoWhisper/Info.plist`:
- Update `CFBundleShortVersionString` (e.g., "1.0.0")
- Update `CFBundleVersion` (e.g., "1")

### 2.2 Configure Signing

1. Open Xcode project
2. Select RepoWhisper target
3. Go to "Signing & Capabilities"
4. Enable "Automatically manage signing"
5. Select your Developer ID Application certificate

### 2.3 Build Release Version

```bash
cd frontend

# Clean build folder
xcodebuild clean -project RepoWhisper.xcodeproj -scheme RepoWhisper -configuration Release

# Build for release
xcodebuild archive \
  -project RepoWhisper.xcodeproj \
  -scheme RepoWhisper \
  -configuration Release \
  -archivePath ./build/RepoWhisper.xcarchive

# Export app
xcodebuild -exportArchive \
  -archivePath ./build/RepoWhisper.xcarchive \
  -exportPath ./build/export \
  -exportOptionsPlist ExportOptions.plist
```

Create `ExportOptions.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
    <key>signingStyle</key>
    <string>automatic</string>
</dict>
</plist>
```

- [ ] Version numbers updated
- [ ] Signing configured
- [ ] Release build successful
- [ ] App exported to build/export/

## Phase 3: Notarization

### 3.1 Create App-Specific Password

1. Go to https://appleid.apple.com/account/manage
2. Generate app-specific password
3. Save it securely

### 3.2 Create Notarization Keychain Item

```bash
xcrun notarytool store-credentials "RepoWhisper-Notary" \
  --apple-id "your-email@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "APP_SPECIFIC_PASSWORD"
```

### 3.3 Submit for Notarization

```bash
# Create a zip for notarization
cd frontend/build/export
ditto -c -k --sequesterRsrc --keepParent RepoWhisper.app RepoWhisper.zip

# Submit for notarization
xcrun notarytool submit RepoWhisper.zip \
  --keychain-profile "RepoWhisper-Notary" \
  --wait

# Staple the notarization ticket
xcrun stapler staple RepoWhisper.app

# Verify
xcrun stapler validate RepoWhisper.app
spctl -a -vvv -t install RepoWhisper.app
```

- [ ] App-specific password created
- [ ] Credentials stored in keychain
- [ ] App submitted and notarized
- [ ] Ticket stapled successfully
- [ ] Gatekeeper validation passes

## Phase 4: DMG Creation

### 4.1 Install create-dmg

```bash
brew install create-dmg
```

### 4.2 Create Installer DMG

```bash
cd frontend/build/export

create-dmg \
  --volname "RepoWhisper" \
  --volicon "../../../assets/AppIcon.icns" \
  --window-pos 200 120 \
  --window-size 800 400 \
  --icon-size 100 \
  --icon "RepoWhisper.app" 200 190 \
  --hide-extension "RepoWhisper.app" \
  --app-drop-link 600 185 \
  "RepoWhisper-1.0.0.dmg" \
  "RepoWhisper.app"
```

### 4.3 Sign the DMG

```bash
codesign --sign "Developer ID Application: YOUR_NAME (TEAM_ID)" \
  --timestamp \
  --options runtime \
  RepoWhisper-1.0.0.dmg

# Verify signature
codesign -vvv --deep --strict RepoWhisper-1.0.0.dmg
spctl -a -t open --context context:primary-signature -v RepoWhisper-1.0.0.dmg
```

### 4.4 Notarize the DMG

```bash
# Submit DMG for notarization
xcrun notarytool submit RepoWhisper-1.0.0.dmg \
  --keychain-profile "RepoWhisper-Notary" \
  --wait

# Staple the ticket
xcrun stapler staple RepoWhisper-1.0.0.dmg

# Verify
xcrun stapler validate RepoWhisper-1.0.0.dmg
spctl -a -vvv -t install RepoWhisper-1.0.0.dmg
```

- [ ] DMG created with proper layout
- [ ] DMG signed with Developer ID
- [ ] DMG notarized successfully
- [ ] Ticket stapled to DMG
- [ ] Gatekeeper validation passes

## Phase 5: Pre-Release Verification

### 5.1 Security Audit

```bash
# Run security audit script
cd /path/to/RepoWhisper
./scripts/audit_secrets.sh
```

Expected output: ✅ All checks passed

### 5.2 Test Installation

1. Mount the DMG on a **clean Mac** (not your dev machine)
2. Drag RepoWhisper.app to Applications
3. Right-click → Open (first launch)
4. Verify Gatekeeper accepts it

### 5.3 Functional Testing

Run through the 8 acceptance tests:

1. **Fresh Launch Test**
   - [ ] Delete Application Support data
   - [ ] Launch app
   - [ ] Onboarding screen appears
   - [ ] Can add first repository

2. **Add Repository Test**
   - [ ] Click "Add Repository"
   - [ ] Select a folder
   - [ ] allowlist.json created in Application Support
   - [ ] Backend status shows "Healthy"

3. **Index Repository Test**
   - [ ] Navigate to Indexing tab
   - [ ] Select repository
   - [ ] Choose indexing mode (Smart recommended)
   - [ ] Click "Start Indexing"
   - [ ] Progress bar animates
   - [ ] Completion shows chunk count > 0
   - [ ] Backend status shows updated count

4. **Search Test**
   - [ ] Navigate to Search tab
   - [ ] Enter query: "function that handles authentication"
   - [ ] Results appear with:
     - File paths
     - Line numbers
     - Code snippets
     - Relevance scores

5. **Result Actions Test**
   - [ ] Click "Copy" on a result
   - [ ] Button changes to "Copied"
   - [ ] Code is in clipboard
   - [ ] Click "Finder" - file location opens
   - [ ] Click "Editor" - file opens in default editor

6. **Persistence Test**
   - [ ] Close and reopen app
   - [ ] Navigate to Search
   - [ ] Enter same query
   - [ ] Results still appear (data persisted)

7. **Clear Index Test**
   - [ ] Navigate to Repositories tab
   - [ ] Remove a repository
   - [ ] Search for content from that repo
   - [ ] No results found

8. **Audio Upload Test**
   - [ ] Navigate to Search tab
   - [ ] Click "Upload" button
   - [ ] Select an audio file
   - [ ] Transcription appears in search box
   - [ ] Search automatically triggered
   - [ ] Results display

### 5.4 Performance Checks

- [ ] Backend starts in < 5 seconds
- [ ] Health check responds in < 100ms
- [ ] Search latency < 100ms for indexed repos
- [ ] Memory usage reasonable (< 500MB idle)

### 5.5 Error Handling

- [ ] Test with no internet (should work)
- [ ] Test with corrupted allowlist (graceful error)
- [ ] Test with invalid repo path (clear error message)
- [ ] Test with no microphone permission (prompt user)

## Phase 6: Distribution

### 6.1 Create Release Notes

Create `RELEASE_NOTES.md`:
```markdown
# RepoWhisper v1.0.0

## Features
- Voice-powered code search across your repositories
- Local-first: All processing happens on your Mac
- Secure: Only accesses folders you explicitly approve
- Fast: Sub-100ms semantic search with vector embeddings
- Privacy: Your code never leaves your computer

## Requirements
- macOS 14.0 or later
- Apple Silicon (M1/M2/M3) or Intel processor

## Installation
1. Download RepoWhisper-1.0.0.dmg
2. Open the DMG
3. Drag RepoWhisper to Applications
4. Launch from Applications folder

## First Launch
1. Grant folder access when prompted
2. Allow microphone access for voice search (optional)
3. Add your first repository
4. Start indexing your code

## Support
- Documentation: https://github.com/your-repo/repowhisper
- Issues: https://github.com/your-repo/repowhisper/issues
```

### 6.2 Upload to Distribution

Options:
- **GitHub Releases**: Create a new release, upload DMG
- **Website**: Upload to your hosting
- **TestFlight**: For beta testing (requires App Store Connect)

### 6.3 Announce

- [ ] Tag release in Git: `git tag -a v1.0.0 -m "Release 1.0.0"`
- [ ] Push tag: `git push origin v1.0.0`
- [ ] Create GitHub Release with DMG attached
- [ ] Update README.md with download link
- [ ] Announce on relevant channels

## Troubleshooting

### Notarization Failed

Check the notarization log:
```bash
xcrun notarytool log <SUBMISSION_ID> \
  --keychain-profile "RepoWhisper-Notary"
```

Common issues:
- Unsigned embedded binaries (check backend binaries)
- Missing entitlements
- Hardened runtime issues

### Gatekeeper Rejection

```bash
# Check why Gatekeeper is rejecting
spctl -a -vvv -t install RepoWhisper.app

# If needed, reset Gatekeeper for testing
sudo spctl --master-disable  # BE CAREFUL - dev only
```

### Backend Not Starting

Check logs in `~/Library/Application Support/RepoWhisper/logs/`:
- `backend_stdout.log`
- `backend_stderr.log`

Common issues:
- Missing Python dependencies in binary
- Architecture mismatch
- Permission issues with socket path

## Post-Release

- [ ] Monitor crash reports (Xcode Organizer)
- [ ] Track download metrics
- [ ] Gather user feedback
- [ ] Plan next release

## Security

**Important**: Never commit:
- Developer ID certificates
- App-specific passwords
- Team ID (if private)
- Keychain credentials

Keep these in secure password manager or environment variables.

---

## Quick Reference Commands

```bash
# Full ship sequence
cd backend && ./build_binaries.sh
cd ../frontend
xcodebuild archive -archivePath ./build/RepoWhisper.xcarchive
xcodebuild -exportArchive -archivePath ./build/RepoWhisper.xcarchive -exportPath ./build/export
cd build/export
ditto -c -k --sequesterRsrc --keepParent RepoWhisper.app RepoWhisper.zip
xcrun notarytool submit RepoWhisper.zip --keychain-profile "RepoWhisper-Notary" --wait
xcrun stapler staple RepoWhisper.app
create-dmg --volname "RepoWhisper" RepoWhisper-1.0.0.dmg RepoWhisper.app
codesign --sign "Developer ID Application: YOUR_NAME" RepoWhisper-1.0.0.dmg
xcrun notarytool submit RepoWhisper-1.0.0.dmg --keychain-profile "RepoWhisper-Notary" --wait
xcrun stapler staple RepoWhisper-1.0.0.dmg
```

**Good luck shipping! 🚀**
