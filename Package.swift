// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "FSRS",
    platforms: [
        .iOS(.v16),
        .macOS(.v13),
        .watchOS(.v9),
        .tvOS(.v16),
    ],
    products: [
        .library(
            name: "FSRS",
            targets: ["FSRS"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/realm/SwiftLint.git", from: "0.62.2")
    ],
    targets: [
        .target(
            name: "FSRS",
            dependencies: [],
            path: "Sources/FSRS",
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint")
            ],
        ),
        .testTarget(
            name: "FSRSTests",
            dependencies: ["FSRS"],
            path: "Tests/FSRS",
            exclude: ["README.md"],
            plugins: [
                .plugin(name: "SwiftLintBuildToolPlugin", package: "SwiftLint")
            ]
        ),
    ]
)
