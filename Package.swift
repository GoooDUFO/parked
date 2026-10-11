// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Parked",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Parked", path: "Sources/Parked")
    ]
)
