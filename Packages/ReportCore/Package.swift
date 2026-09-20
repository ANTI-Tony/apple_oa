// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ReportCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "ReportCore", targets: ["ReportCore"]),
        .library(name: "ReportCLIKit", targets: ["ReportCLIKit"]),
        .executable(name: "reportcard", targets: ["reportcard"]),
    ],
    targets: [
        .target(
            name: "ReportCore",
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        // Command-line front end: headless rendering, accessibility linting for
        // CI pipelines, and the static gallery published to GitHub Pages.
        .target(
            name: "ReportCLIKit",
            dependencies: ["ReportCore"],
            swiftSettings: [
                .enableUpcomingFeature("ExistentialAny"),
            ]
        ),
        .executableTarget(
            name: "reportcard",
            dependencies: ["ReportCLIKit"]
        ),
        .testTarget(
            name: "ReportCoreTests",
            dependencies: ["ReportCore"]
        ),
        .testTarget(
            name: "ReportCLIKitTests",
            dependencies: ["ReportCLIKit", "ReportCore"]
        ),
    ]
)
