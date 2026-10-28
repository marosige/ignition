// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Ignition",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "Ignition", targets: ["Ignition"])
    ],
    targets: [
        .target(
            name: "IgnitionCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .executableTarget(
            name: "Ignition",
            dependencies: ["IgnitionCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "IgnitionCoreTests",
            dependencies: ["IgnitionCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
