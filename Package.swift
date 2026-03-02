// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "DressageCaller",
    platforms: [
        .iOS(.v18)
    ],
    products: [
        .library(
            name: "DressageCaller",
            targets: ["DressageCaller"]
        )
    ],
    targets: [
        .target(
            name: "DressageCaller",
            path: "DressageCaller"
        )
    ]
)
