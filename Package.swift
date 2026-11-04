// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SmartSwitchKit",
    platforms: [.macOS(.v12)],
    products: [
        .library(name: "SmartSwitchKit", targets: ["SmartSwitchKit"]),
        .executable(name: "analyze", targets: ["AnalyzeCLI"]),
        .executable(name: "gen-boundary-data", targets: ["GenBoundaryData"]),
        .executable(name: "measure-boundary", targets: ["MeasureBoundary"]),
    ],
    targets: [
        .target(
            name: "SmartSwitchKit",
            resources: [
                .copy("Resources/english-top3000.txt"),
                .copy("Resources/english-nosplit.txt"),
                .copy("Resources/syllable-weights.txt"),
            ]
        ),
        .executableTarget(name: "AnalyzeCLI", dependencies: ["SmartSwitchKit"]),
        .executableTarget(name: "GenBoundaryData", dependencies: ["SmartSwitchKit"]),
        .executableTarget(name: "MeasureBoundary", dependencies: ["SmartSwitchKit"]),
        .testTarget(name: "SmartSwitchKitTests", dependencies: ["SmartSwitchKit"]),
    ]
)
