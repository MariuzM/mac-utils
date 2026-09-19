// swift-tools-version:6.4
import PackageDescription

let package = Package(
    name: "mac-utils",
    platforms: [
        .macOS("27.0")
    ],
    targets: [
        .target(
            name: "FolderKit",
            path: "Sources/FolderKit"
        ),
        .executableTarget(
            name: "MacUtils",
            dependencies: ["FolderKit"],
            path: "Sources/MacUtils"
        ),
        .executableTarget(
            name: "FolderHelper",
            dependencies: ["FolderKit"],
            path: "Sources/FolderHelper"
        ),
    ]
)
