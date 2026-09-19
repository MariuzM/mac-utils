// swift-tools-version:6.4
import PackageDescription

let package = Package(
    name: "FolderKit",
    platforms: [.macOS("27.0")],
    products: [
        .library(name: "FolderKit", targets: ["FolderKit"])
    ],
    targets: [
        .target(
            name: "FolderKit",
            path: "Sources/FolderKit"
        )
    ]
)
