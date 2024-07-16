// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NVAppUpdater",
    platforms: [.macOS(.v11)],
    products: [
        .library(name: "NVAppUpdater", targets: ["NVAppUpdater"]),
    ],
    dependencies: [
        .package(url: "https://github.com/nicoverbruggen/NVAlert", from: "1.0.0")
    ],
    targets: [
        .target(name: "NVAppUpdater", dependencies: ["NVAlert"]),
    ]
)
