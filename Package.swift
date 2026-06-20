// swift-tools-version: 6.0
import Foundation
import PackageDescription

/// Orchard — decentralized swarm-intelligence runtime.
/// Platforms are kept broad so the core builds and tests on CI runners without the iOS/macOS 26
/// SDK. The Foundation Models adapter is compiled in only where `canImport(FoundationModels)`
/// succeeds (Xcode 26+ / OS 26+).
///
/// The Metal-accelerated MLX shard executor pulls in the heavyweight `mlx-swift` dependency and
/// needs a real GPU at runtime, so it is opt-in: set ORCHARD_ENABLE_MLX=1 (see `just mlx-demo`).
/// CI leaves it unset, keeping the build dependency-light and green. Same pattern as the other
/// hardware-bound capabilities — real adapter present, gated, never blocking the core.
let enableMLX = ProcessInfo.processInfo.environment["ORCHARD_ENABLE_MLX"] != nil

var products: [Product] = [
    .library(name: "OrchardProtocol", targets: ["OrchardProtocol"]),
    .library(name: "OrchardNode", targets: ["OrchardNode"]),
    .library(name: "OrchardSwarm", targets: ["OrchardSwarm"]),
    .library(name: "OrchardRouter", targets: ["OrchardRouter"]),
    .library(name: "OrchardCrypto", targets: ["OrchardCrypto"]),
    .library(name: "OrchardPilot", targets: ["OrchardPilot"]),
    .executable(name: "orchard-demo", targets: ["orchard-demo"]),
    .executable(name: "orchard-pilot", targets: ["orchard-pilot"]),
]

var dependencies: [Package.Dependency] = []

/// mlx-swift requires macOS 14+; the core otherwise supports macOS 13.
let platforms: [SupportedPlatform] = enableMLX
    ? [.macOS(.v14), .iOS(.v16)]
    : [.macOS(.v13), .iOS(.v16)]

var targets: [Target] = [
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

if enableMLX {
    dependencies.append(.package(url: "https://github.com/ml-explore/mlx-swift.git", from: "0.21.0"))
    products.append(.library(name: "OrchardMLX", targets: ["OrchardMLX"]))
    products.append(.executable(name: "orchard-mlx-demo", targets: ["orchard-mlx-demo"]))
    targets.append(.target(
        name: "OrchardMLX",
        dependencies: [
            "OrchardSwarm",
            .product(name: "MLX", package: "mlx-swift"),
        ]
    ))
    targets.append(.executableTarget(
        name: "orchard-mlx-demo",
        dependencies: ["OrchardMLX", "OrchardSwarm", "OrchardProtocol"]
    ))
    targets.append(.testTarget(
        name: "OrchardMLXTests",
        dependencies: ["OrchardMLX", "OrchardSwarm", "OrchardProtocol"]
    ))
}

let package = Package(
    name: "Orchard",
    platforms: platforms,
    products: products,
    dependencies: dependencies,
    targets: targets
)
