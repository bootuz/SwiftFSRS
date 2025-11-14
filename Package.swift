// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FSRS",
    platforms: [
        .iOS(.v13),
        .macOS(.v10_15),
        .watchOS(.v6),
        .tvOS(.v13)
    ],
    products: [
        .library(
            name: "FSRS",
            targets: ["FSRS"]
        ),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "FSRS",
            dependencies: [],
            path: "Sources/FSRS"
        ),
        .testTarget(
            name: "FSRSTests",
            dependencies: ["FSRS"],
            path: "Tests/FSRS"
        ),
    ]
)

