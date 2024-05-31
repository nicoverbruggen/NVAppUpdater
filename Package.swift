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
    targets: [
        .target(name: "NVAppUpdater"),
    ]
)
