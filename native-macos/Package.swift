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
            name: "NetworkingKit",
            targets: ["NetworkingKit"]
        ),
        .library(
            name: "AuthFeature",
            targets: ["AuthFeature"]
        ),
        .library(
            name: "SettingsFeature",
            targets: ["SettingsFeature"]
        ),
        .library(
            name: "ConsoleFeature",
            targets: ["ConsoleFeature"]
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
            name: "NetworkingKit",
            dependencies: ["SharedDomain"],
            path: "Sources/NetworkingKit"
        ),
        .target(
            name: "AuthFeature",
            dependencies: ["SharedDomain", "PersistenceKit", "NetworkingKit"],
            path: "Sources/AuthFeature"
        ),
        .target(
            name: "SettingsFeature",
            dependencies: ["SharedDomain", "PersistenceKit"],
            path: "Sources/SettingsFeature"
        ),
        .target(
            name: "ConsoleFeature",
            dependencies: ["SharedDomain", "PersistenceKit"],
            path: "Sources/ConsoleFeature"
        ),
        .target(
            name: "SupportKit",
            path: "Sources/SupportKit"
        ),
        .target(
            name: "AppShell",
            dependencies: ["SharedDomain", "SupportKit", "PersistenceKit", "NetworkingKit", "AuthFeature", "SettingsFeature", "ConsoleFeature"],
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
            name: "NetworkingKitTests",
            dependencies: ["NetworkingKit", "SharedDomain"],
            path: "Tests/NetworkingKitTests"
        ),
        .testTarget(
            name: "AuthFeatureTests",
            dependencies: ["AuthFeature", "SharedDomain", "PersistenceKit"],
            path: "Tests/AuthFeatureTests"
        ),
        .testTarget(
            name: "SettingsFeatureTests",
            dependencies: ["SettingsFeature", "SharedDomain", "PersistenceKit"],
            path: "Tests/SettingsFeatureTests"
        ),
        .testTarget(
            name: "ConsoleFeatureTests",
            dependencies: ["ConsoleFeature", "SharedDomain", "PersistenceKit"],
            path: "Tests/ConsoleFeatureTests"
        ),
        .testTarget(
            name: "AppShellTests",
            dependencies: ["AppShell"],
            path: "Tests/AppShellTests"
        )
    ]
)
