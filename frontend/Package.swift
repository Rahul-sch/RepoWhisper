// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "RepoWhisper",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(
            name: "RepoWhisper",
            targets: ["RepoWhisper"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/supabase/supabase-swift", from: "2.0.0")
    ],
    targets: [
        .executableTarget(
            name: "RepoWhisper",
            dependencies: [
                .product(name: "Supabase", package: "supabase-swift")
            ],
            path: "RepoWhisper"
        )
    ]
)

