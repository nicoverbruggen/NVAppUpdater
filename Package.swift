// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "NVAppUpdater",
    defaultLocalization: "en",
    platforms: [.macOS(.v11)],
    products: [
        .library(name: "NVAppUpdater", targets: ["NVAppUpdater"]),
    ],
    dependencies: [
        .package(name: "NVAlert", path: "/Users/nicoverbruggen/Code/SwiftPM/NVAlert")
        // .package(url: "https://github.com/nicoverbruggen/NVAlert", branch: "main")
    ],
    targets: [
        .target(name: "NVAppUpdater", dependencies: ["NVAlert"]),
    ]
)
