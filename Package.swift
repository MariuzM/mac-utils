// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MacOSUtility",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "MacOSUtility",
            path: "Sources/MacOSUtility"
        )
    ]
)
