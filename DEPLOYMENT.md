# Deployment

RepoWhisper ships as a signed macOS app with an architecture-matched Python sidecar.

## 1. Build the backend

```bash
cd backend
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
cd ..
./build_binaries.sh
./prebake_models.sh  # optional; enables offline first launch
```

The executable and optional model cache are staged under `frontend/RepoWhisper/Resources`. The Xcode `Embed Local Backend` phase copies them into the app and fails Release builds if the matching executable is absent.

## 2. Archive and export

Open `frontend/RepoWhisper.xcodeproj`, select the Release configuration, then use Product → Archive. Export with a Developer ID Application certificate and hardened runtime enabled.

Verify before packaging:

```bash
codesign --verify --deep --strict --verbose=2 /path/to/RepoWhisper.app
spctl --assess --type execute --verbose=2 /path/to/RepoWhisper.app
```

## 3. Create and notarize the DMG

```bash
brew install create-dmg
./create_dmg.sh /path/to/RepoWhisper.app ./dist
xcrun notarytool submit ./dist/RepoWhisper-0.1.0.dmg --keychain-profile AC_PASSWORD --wait
xcrun stapler staple ./dist/RepoWhisper-0.1.0.dmg
xcrun stapler validate ./dist/RepoWhisper-0.1.0.dmg
```

Test the final artifact on a clean macOS 14+ account, including first repository approval, model availability, microphone permission, Screen Recording permission, indexing, voice search, and app relaunch.
