// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SmartSwitchKit",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "SmartSwitchKit", targets: ["SmartSwitchKit"]),
        .executable(name: "analyze", targets: ["AnalyzeCLI"]),
    ],
    targets: [
        .target(name: "SmartSwitchKit"),
        .executableTarget(name: "AnalyzeCLI", dependencies: ["SmartSwitchKit"]),
        .testTarget(name: "SmartSwitchKitTests", dependencies: ["SmartSwitchKit"]),
    ]
)
