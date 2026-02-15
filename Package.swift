// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Seditor",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Seditor", targets: ["Seditor"])
    ],
    targets: [
        .executableTarget(
            name: "Seditor",
            path: "Sources/Seditor"
        )
    ]
)
