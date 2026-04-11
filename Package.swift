// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "ccSwitchboardMac",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "ccSwitchboardMac", targets: ["ccSwitchboardMac"])
    ],
    targets: [
        .executableTarget(
            name: "ccSwitchboardMac",
            path: "Sources/ccSwitchboardMac"
        )
    ]
)
