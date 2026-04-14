// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "XStreamingMacNative",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "SharedDomain",
            targets: ["SharedDomain"]
        ),
        .library(
            name: "PersistenceKit",
            targets: ["PersistenceKit"]
        ),
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
            name: "SharedDomain",
            path: "Sources/SharedDomain"
        ),
        .target(
            name: "PersistenceKit",
            dependencies: ["SharedDomain"],
            path: "Sources/PersistenceKit"
        ),
        .target(
            name: "SupportKit",
            path: "Sources/SupportKit"
        ),
        .target(
            name: "AppShell",
            dependencies: ["SharedDomain", "SupportKit", "PersistenceKit"],
            path: "Sources/AppShell"
        ),
        .executableTarget(
            name: "XStreamingMacApp",
            dependencies: ["AppShell"],
            path: "App"
        ),
        .testTarget(
            name: "SharedDomainTests",
            dependencies: ["SharedDomain"],
            path: "Tests/SharedDomainTests"
        ),
        .testTarget(
            name: "PersistenceKitTests",
            dependencies: ["PersistenceKit", "SharedDomain"],
            path: "Tests/PersistenceKitTests"
        ),
        .testTarget(
            name: "AppShellTests",
            dependencies: ["AppShell"],
            path: "Tests/AppShellTests"
        )
    ]
)
