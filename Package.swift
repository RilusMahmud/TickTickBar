// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "TickTickBar",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "TickTickBar", path: "Sources/TickTickBar")
    ]
)
