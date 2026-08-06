// swift-tools-version: 5.9
// La direttiva swift-tools-version dichiara la versione minima di Swift richiesta.

import PackageDescription

// Definisce l'eseguibile macOS e i due target dedicati ai test logici e di interfaccia.
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
