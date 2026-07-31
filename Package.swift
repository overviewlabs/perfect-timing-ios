// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "PerfectTiming",
    platforms: [.iOS(.v17)],
    products: [.library(name: "PerfectTimingCore", targets: ["PerfectTimingCore"])],
    targets: [
        .target(name: "PerfectTimingCore", path: "Sources/PerfectTimingCore"),
        .testTarget(name: "PerfectTimingCoreTests", dependencies: ["PerfectTimingCore"], path: "Tests/PerfectTimingCoreTests")
    ]
)
