// swift-tools-version:5.5
import PackageDescription

let package = Package(
    name: "StableRadio-iOS",
    platforms: [
        .iOS(.v12)
    ],
    products: [
        .library(
            name: "StableRadio-iOS",
            targets: ["StableRadio-iOS"]
        )
    ],
    dependencies: [
        .package(path: "../StableRadioCore")
    ],
    targets: [
        .target(
            name: "StableRadio-iOS",
            dependencies: ["StableRadioCore"],
            path: "StableRadio-iOS"
        )
    ]
)
