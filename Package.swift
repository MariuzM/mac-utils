// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacOSUtility",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .target(
            name: "FolderKit",
            path: "Sources/FolderKit"
        ),
        .executableTarget(
            name: "MacOSUtility",
            dependencies: ["FolderKit"],
            path: "Sources/MacOSUtility"
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
            name: "MacOSUtilityTests",
            dependencies: ["MacOSUtility"],
            path: "Tests/MacOSUtilityTests"
        ),
    ]
)
