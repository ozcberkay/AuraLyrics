// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AuraLyrics",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "AuraLyrics", targets: ["AuraLyrics"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AuraLyricsCore",
            path: "AuraLyricsCore"
        ),
        .executableTarget(
            name: "AuraLyrics",
            dependencies: ["AuraLyricsCore"],
            path: "AuraLyrics",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "AuraLyricsCoreTests",
            dependencies: ["AuraLyricsCore"],
            path: "Tests/AuraLyricsCoreTests"
        ),
        .testTarget(
            name: "AuraLyricsTests",
            dependencies: [],
            path: "Tests/AuraLyricsTests"
        )
    ]
)
