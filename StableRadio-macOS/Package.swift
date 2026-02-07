// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "StableRadio-macOS",
    platforms: [
        .macOS(.v11)
    ],
    products: [
        .executable(
            name: "StableRadio-macOS",
            targets: ["StableRadio-macOS"]
        )
    ],
    dependencies: [
        .package(path: "../StableRadioCore")
    ],
    targets: [
        .executableTarget(
            name: "StableRadio-macOS",
            dependencies: ["StableRadioCore"],
            path: "StableRadio-macOS"
        )
    ]
)
