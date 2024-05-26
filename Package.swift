// swift-tools-version: 5.10
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AppUpdater",
    platforms: [.macOS(.v11)],
    products: [
        .library(name: "AppUpdater", targets: ["AppUpdater"]),
    ],
    targets: [
        .target(name: "AppUpdater"),
    ]
)
