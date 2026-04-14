// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XStreamingMacNative",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AppShell",
            targets: ["AppShell"]
        ),
        .library(
            name: "SupportKit",
            targets: ["SupportKit"]
        ),
        .executable(
            name: "XStreamingMacApp",
            targets: ["XStreamingMacApp"]
        )
    ],
    targets: [
        .target(
            name: "SupportKit",
            path: "Sources/SupportKit"
        ),
        .target(
            name: "AppShell",
            dependencies: ["SupportKit"],
            path: "Sources/AppShell"
        ),
        .executableTarget(
            name: "XStreamingMacApp",
            dependencies: ["AppShell"],
            path: "App"
        ),
        .testTarget(
            name: "AppShellTests",
            dependencies: ["AppShell"],
            path: "Tests/AppShellTests"
        )
    ]
)
