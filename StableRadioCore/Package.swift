// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "StableRadioCore",
    platforms: [
        .macOS(.v11),
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "StableRadioCore",
            targets: ["StableRadioCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "StableRadioCore",
            dependencies: []
        ),
        .testTarget(
            name: "StableRadioCoreTests",
            dependencies: ["StableRadioCore"]
        )
    ]
)
