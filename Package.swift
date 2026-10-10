// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "ResourceMonitor",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "MonitorCore",
            linkerSettings: [.linkedFramework("IOKit")]
        ),
        .executableTarget(
            name: "ResourceMonitor",
            dependencies: ["MonitorCore"]
        ),
        .testTarget(
            name: "MonitorCoreTests",
            dependencies: ["MonitorCore"],
            // The Command Line Tools keep the Swift Testing macro plugin outside the default search path.
            swiftSettings: [.unsafeFlags(["-plugin-path", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"])]
        ),
    ],
    swiftLanguageModes: [.v5]
)
