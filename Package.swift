// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "DeepSeekCostWidget",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "DeepSeekCostWidget",
            path: "Sources/DeepSeekCostWidget",
            resources: [
                .copy("AppIcon.icns")
            ]
        )
    ]
)
