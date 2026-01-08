# Xcode Project Setup

## Quick Setup

1. **Open Xcode** and create a new project:
   - File > New > Project
   - Choose "macOS" > "App"
   - Product Name: `RepoWhisper`
   - Interface: `SwiftUI`
   - Language: `Swift`
   - Save to: `frontend/` directory

2. **Replace the default files** with the files from `RepoWhisper/` folder

3. **Add Supabase Swift SDK**:
   - File > Add Package Dependencies
   - URL: `https://github.com/supabase/supabase-swift`
   - Version: `2.0.0` or latest
   - Add to target: `RepoWhisper`

4. **Configure Info.plist**:
   - The `Info.plist` is already created in the `RepoWhisper/` folder
   - Make sure it's included in the Xcode project
   - Or add the keys manually in Xcode's Info tab:
     - `Privacy - Microphone Usage Description`: "RepoWhisper needs microphone access..."
     - `Privacy - AppleEvents Usage Description`: "RepoWhisper needs to control..."

5. **Add App Capabilities**:
   - Select project > Target > Signing & Capabilities
   - Add "App Sandbox" if needed
   - Enable "Outgoing Connections (Client)"

6. **Build and Run**:
   - Product > Build (⌘B)
   - Product > Run (⌘R)

## Alternative: Swift Package Manager

If you prefer SPM, create a `Package.swift` in the `frontend/` directory:

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RepoWhisper",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "RepoWhisper",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ]
        )
    ]
)
```

Then build with: `swift build`

