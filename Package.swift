// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AIMemoryAssistant",
    platforms: [
        .iOS(.v17)
    ],
    products: [
        .library(
            name: "AIMemoryAssistant",
            targets: ["AIMemoryAssistant"]
        )
    ],
    targets: [
        .target(
            name: "AIMemoryAssistant",
            path: "Sources/AIMemoryAssistant",
            resources: [
                .process("Resources")
            ]
        )
    ]
)
