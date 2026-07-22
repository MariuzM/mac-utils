// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "mac-utils",
    platforms: [
        .macOS(.v13)
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
        .testTarget(
            name: "FolderKitTests",
            dependencies: ["FolderKit"],
            path: "Tests/FolderKitTests"
        ),
        .testTarget(
            name: "MacUtilsTests",
            dependencies: ["MacUtils"],
            path: "Tests/MacUtilsTests"
        ),
    ]
)
