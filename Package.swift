// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "CopyLab",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15)
    ],
    products: [
        .library(
            name: "CopyLab",
            targets: ["CopyLab"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "CopyLab",
            dependencies: [])
    ]
)
