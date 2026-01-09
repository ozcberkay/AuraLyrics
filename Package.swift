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
    targets: [
        .executableTarget(
            name: "AuraLyrics",
            dependencies: [],
            path: "AuraLyrics",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
