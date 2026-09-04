# Xcode setup

Install Xcode 15+ and XcodeGen, then generate the project from the checked-in specification:

```bash
brew install xcodegen
cd frontend
./setup_xcode.sh
```

Open `RepoWhisper.xcodeproj`, select your development team if signing is required, and run the `RepoWhisper` scheme. The deployment target is macOS 14. No third-party Swift package is required.

The Release build phase expects `RepoWhisper/Resources/repowhisper-backend-<architecture>`. Generate it with the repository-root `build_binaries.sh` before archiving.
