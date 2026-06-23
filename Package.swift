// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "NowTimeline",
    platforms: [.iOS("26.0"), .macOS(.v15)],
    products: [
        .library(name: "NowTimelineCore", targets: ["NowTimelineCore"])
    ],
    targets: [
        .target(name: "NowTimelineCore"),
        .testTarget(
            name: "NowTimelineCoreTests",
            dependencies: ["NowTimelineCore"]
        )
    ]
)
