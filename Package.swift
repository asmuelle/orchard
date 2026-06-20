// swift-tools-version: 6.0
import PackageDescription

/// Orchard — decentralized swarm-intelligence runtime.
/// Platforms are kept broad so the core (protocol + scheduler) builds and tests on CI
/// runners without the iOS/macOS 26 SDK. The Foundation Models adapter is compiled in
/// only where `canImport(FoundationModels)` succeeds (Xcode 26+ / OS 26+).
let package = Package(
    name: "Orchard",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
    ],
    products: [
        .library(name: "OrchardProtocol", targets: ["OrchardProtocol"]),
        .library(name: "OrchardNode", targets: ["OrchardNode"]),
        .library(name: "OrchardSwarm", targets: ["OrchardSwarm"]),
        .library(name: "OrchardRouter", targets: ["OrchardRouter"]),
        .library(name: "OrchardCrypto", targets: ["OrchardCrypto"]),
        .library(name: "OrchardPilot", targets: ["OrchardPilot"]),
        .executable(name: "orchard-demo", targets: ["orchard-demo"]),
        .executable(name: "orchard-pilot", targets: ["orchard-pilot"]),
    ],
    targets: [
        .target(name: "OrchardProtocol"),
        .target(
            name: "OrchardNode",
            dependencies: ["OrchardProtocol"]
        ),
        .target(
            name: "OrchardSwarm",
            dependencies: ["OrchardProtocol"]
        ),
        .target(
            name: "OrchardRouter",
            dependencies: ["OrchardProtocol"]
        ),
        .target(name: "OrchardCrypto"),
        .target(
            name: "OrchardPilot",
            dependencies: [
                "OrchardProtocol",
                "OrchardNode",
                "OrchardSwarm",
                "OrchardRouter",
                "OrchardCrypto",
            ]
        ),
        .executableTarget(
            name: "orchard-pilot",
            dependencies: ["OrchardPilot", "OrchardProtocol"]
        ),
        .executableTarget(
            name: "orchard-demo",
            dependencies: [
                "OrchardNode",
                "OrchardSwarm",
                "OrchardRouter",
                "OrchardCrypto",
                "OrchardProtocol",
            ]
        ),
        .testTarget(
            name: "OrchardProtocolTests",
            dependencies: ["OrchardProtocol"]
        ),
        .testTarget(
            name: "OrchardNodeTests",
            dependencies: ["OrchardNode", "OrchardProtocol"]
        ),
        .testTarget(
            name: "OrchardSwarmTests",
            dependencies: ["OrchardSwarm", "OrchardProtocol"]
        ),
        .testTarget(
            name: "OrchardRouterTests",
            dependencies: ["OrchardRouter", "OrchardProtocol"]
        ),
        .testTarget(
            name: "OrchardCryptoTests",
            dependencies: ["OrchardCrypto"]
        ),
        .testTarget(
            name: "OrchardPilotTests",
            dependencies: ["OrchardPilot", "OrchardProtocol"]
        ),
    ]
)
