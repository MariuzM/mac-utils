// swift-tools-version:6.4
import PackageDescription

let package = Package(
    name: "FolderHelper",
    platforms: [.macOS("27.0")],
    dependencies: [
        .package(path: "../../shared/FolderKit")
    ],
    targets: [
        .executableTarget(
            name: "FolderHelper",
            dependencies: [
                .product(name: "FolderKit", package: "FolderKit")
            ],
            path: "FolderHelper"
        )
    ]
)
