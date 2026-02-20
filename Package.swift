// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "RecallMate",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "RecallMate",
            targets: ["RecallMate"]
        )
    ],
    targets: [
        .target(
            name: "RecallMate",
            path: "Sources/RecallMate",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
