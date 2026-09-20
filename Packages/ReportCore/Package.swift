// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReportCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ReportCore", targets: ["ReportCore"]),
    ],
    targets: [
        .target(
            name: "ReportCore",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        .testTarget(
            name: "ReportCoreTests",
            dependencies: ["ReportCore"]
        ),
    ]
)
