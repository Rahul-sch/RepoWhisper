// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RepoWhisper",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "RepoWhisper",
            targets: ["RepoWhisper"]
        )
    ],
    targets: [
        .executableTarget(
            name: "RepoWhisper",
            path: "RepoWhisper",
            exclude: ["Info.plist", "RepoWhisper.entitlements", "Resources"]
        ),
        .testTarget(
            name: "RepoWhisperTests",
            dependencies: ["RepoWhisper"],
            path: "Tests/RepoWhisperTests"
        )
    ]
)
