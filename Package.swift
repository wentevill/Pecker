// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Pecker",
    platforms: [.iOS("26.0"), .macOS(.v15)],
    products: [
        .library(name: "PeckerCore", targets: ["PeckerCore"])
    ],
    targets: [
        .target(name: "PeckerCore"),
        .testTarget(
            name: "PeckerCoreTests",
            dependencies: ["PeckerCore"]
        )
    ]
)
