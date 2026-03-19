// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "WMA2MP3",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "WMA2MP3",
            targets: ["WMA2MP3"]),
    ],
    targets: [
        .executableTarget(
            name: "WMA2MP3",
            exclude: ["Info.plist"],
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "WMA2MP3Tests",
            dependencies: ["WMA2MP3"]),
        .testTarget(
            name: "WMA2MP3UITests",
            dependencies: ["WMA2MP3"]),
    ]
)
