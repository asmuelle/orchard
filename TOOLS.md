# Orchard — Toolchain, Frameworks & Dependencies

This document enumerates the tools, Apple frameworks, and third-party building blocks Orchard
relies on, plus the local developer toolchain. Keep it in sync with [`DESIGN.md`](./DESIGN.md)
and the `justfile`.

---

## 1. Platform requirements

| Requirement | Version | Why |
| --- | --- | --- |
| macOS | 26+ | On-device Foundation Models APIs |
| iOS / iPadOS | 26+ | AFM + Neural Engine node runtime |
| Xcode | 26+ | Swift 6.x toolchain, FoundationModels SDK |
| Swift | 6.1+ | Strict concurrency, typed throws |

> Orchard's core APIs (Foundation Models framework, AFM structured output / tool calling) were
> introduced with the iOS 26 / macOS 26 generation. Older OSes are out of scope.

## 2. Apple frameworks

| Framework | Used for | Pillar |
| --- | --- | --- |
| **FoundationModels** | On-device LLM inference, `@Generable` structured output, tool calling | Local node execution |
| **Core ML** | Custom model execution on the Neural Engine | Local node execution |
| **MLX** (`mlx-swift`) | Array compute + model sharding across devices | Micro-swarms |
| **Network.framework** | Peer-to-peer LAN transport (`NWConnection`, Bonjour) | Micro-swarms |
| **MultipeerConnectivity** | Device discovery on local Wi-Fi | Micro-swarms |
| **BackgroundTasks** | Scheduling opportunistic overnight work | Scheduler |
| **DeviceCheck / App Attest** | Sybil resistance, device attestation | Privacy / trust |
| **CryptoKit** | Hashing, key agreement, SecAgg masking primitives | Privacy |
| **Combine / Swift Concurrency** | Async task pipelines, structured concurrency | All |

## 3. Privacy & cryptography building blocks

| Component | Approach |
| --- | --- |
| **Secure Aggregation (SecAgg)** | Pairwise additive masking (Bonawitz et al.); masks cancel on sum |
| **Differential Privacy** | Calibrated Gaussian/Laplace noise on gradient deltas; per-round ε budget |
| **Federated Learning** | Local training, masked delta upload, server-side aggregation only |
| **Attestation** | App Attest assertions gate cohort admission |

These live in the `OrchardCrypto` package. No third-party crypto is rolled by hand beyond
CryptoKit primitives — see [security guidance](#7-security).

## 4. Third-party Swift packages (candidate)

| Package | Purpose | Notes |
| --- | --- | --- |
| `mlx-swift` | Tensor compute + sharded inference (`OrchardMLX`) | Apple, Apache-2.0; opt-in (see below) |
| `swift-distributed-actors` | Optional: typed distributed actors for swarm RPC | Evaluate vs. raw Network.framework |
| `swift-collections` | Deques/ordered sets in scheduler | Apple |
| `swift-log` | Structured logging | Apple |
| `swift-argument-parser` | CLI for `orchardctl` dev tool | Apple |

> Prefer battle-tested, first-party (Apple) packages. Audit any non-Apple dependency before adoption.

### MLX shard execution (opt-in)

The Metal-accelerated `MLXShardExecutor` lives in the `OrchardMLX` target, which depends on
`mlx-swift`. It is **gated behind the `ORCHARD_ENABLE_MLX` environment variable** in `Package.swift`:
the dependency, target, and demo are only added when that variable is set. This keeps the default
build (and CI) dependency-light and green, matching how every hardware-bound capability in Orchard
sits behind a seam (`InferenceEngine`, `PeerDiscovery`, `ShardExecutor`).

**Important — build with Xcode, not `swift build`:** mlx-swift uses no-JIT Metal kernels and needs a
precompiled `default.metallib`. SwiftPM's command-line build does not compile `.metal` shaders, so a
bare `swift run` fails to load the Metal library. The provided recipes use `xcodebuild`, which does
compile the metallib:

```bash
just mlx-demo   # ORCHARD_ENABLE_MLX=1 xcodebuild … build, then runs the GPU sharded-pipeline demo
just mlx-test   # runs OrchardMLXTests on Metal
```

Requires Apple Silicon + Xcode. The demo verifies the MLX executor matches the pure-Swift
`LocalShardExecutor` to within ~5e-8.

## 5. Developer toolchain

| Tool | Role | Install |
| --- | --- | --- |
| **just** | Task runner (`justfile`) | `brew install just` |
| **swiftformat** | Code formatting | `brew install swiftformat` |
| **swiftlint** | Linting | `brew install swiftlint` |
| **xcbeautify** | Readable `xcodebuild` output | `brew install xcbeautify` |
| **gh** | GitHub CLI (repo, PR, Pages) | `brew install gh` |

Run `just setup` to install/verify the toolchain and resolve packages.

## 6. CI & hosting

- **GitHub Actions** — build + test matrix (macOS runners), lint, format check.
- **GitHub Pages** — the public site in [`docs/`](./docs), published via `.github/workflows/pages.yml`.

## 7. Security

- Never hardcode secrets; use the system Keychain or CI secrets.
- All network transport over TLS; only masked aggregates cross the WAN.
- Validate every wire message against the `OrchardProtocol` schemas at the boundary.
- Treat all node-supplied results as untrusted: redundant assignment + voting before consensus.

## 8. Local commands

See the `justfile`. Common entry points:

```bash
just setup     # toolchain + package resolution
just build     # build all targets
just test      # run tests
just lint      # swiftlint
just format    # swiftformat
just site      # serve docs/ locally
just ci        # the full check run CI performs
```
