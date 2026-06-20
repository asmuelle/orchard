# 🌳 Orchard

> A decentralized, privacy-preserving swarm-intelligence network powered entirely by idle Apple devices.

Orchard turns millions of idle iPhones, iPads, and Macs into a cooperative supercomputing
network. By coordinating the on-device **Apple Foundation Models (AFM)** and **Apple Neural
Engines (ANE)** of participating devices, Orchard tackles massive, complex problems — from
disease modeling to decentralized web indexing — while keeping **100% of raw user data on
the device**.

---

## Why Orchard

| Conventional cloud AI | Orchard |
| --- | --- |
| Energy-intensive centralized datacenters | Idle silicon you already own |
| Per-token API fees | Zero marginal compute cost |
| Raw data leaves the device | Raw data never leaves the device |
| Owned by a single company | Collectively owned knowledge graph |

## The Four Technical Pillars

1. **Local Node Execution** — Each device is a node running native on-device inference via the
   [Foundation Models framework](https://developer.apple.com/documentation/foundationmodels)
   on the Neural Engine. Opportunistic: runs only when **plugged in, on Wi-Fi, and idle**.
2. **Local Micro-Swarms** — Devices on the same LAN shard high-parameter models across their
   unified memories using MLX-style peer-to-peer clustering.
3. **Global Agentic Workflows** — A Task Router (on Private Cloud Compute) fragments massive
   problems into micro-prompts; millions of edge agents process chunks and return structured
   output for consensus aggregation.
4. **Cryptographic Privacy** — Federated Learning with **Secure Aggregation (SecAgg)** and
   **Differential Privacy**. Only masked gradient updates leave the device.

See [`DESIGN.md`](./DESIGN.md) for the full architecture and [`docs/`](./docs) for the public site.

## Status

🌳 **All five milestones (M1–M5) landed.** `OrchardNode` runs a `NodeRuntime` actor that gates
work behind the opportunistic scheduler and does structured-output inference via Apple's
Foundation Models on OS 26+ (deterministic stub fallback elsewhere). `OrchardSwarm` is the
micro-swarm coordination layer — peer discovery, coordinator election, and a memory-aware
pipeline-parallel layer-shard planner. `OrchardRouter` is the global layer — job fragmentation,
redundant load-balanced assignment, and majority-vote consensus that outvotes and flags faulty
nodes. `OrchardCrypto` is the privacy layer — Bonawitz-style Secure Aggregation (Curve25519 +
exact pairwise mask cancellation) and differential privacy, recovering the federated mean from
masked vectors alone. `OrchardPilot` ties them together end-to-end on a real scientific workload.
The micro-swarm `ShardExecutor` seam is implemented too: a pure-Swift `PipelineRunner` runs a
`ShardPlan` as a distributed forward pass (bit-identical to monolithic), and `OrchardMLX` provides
a real Metal-accelerated executor on `mlx-swift` (opt-in; `just mlx-demo`). `OrchardTransport`
ships activations between pipeline stages over real Network.framework TCP, so `PipelineRunner`
drives a genuine multi-device pipeline (verified over localhost: distributed == monolithic), and
nodes find each other over the LAN via Bonjour auto-discovery (`just bonjour-test`). See the
[roadmap](./DESIGN.md#roadmap).

## Quick start

```bash
just setup     # install toolchain + resolve packages
just build     # build all targets
just test      # run the test suite
just demo      # run one task through a node (Foundation Models on OS 26+, else stub)
just pilot     # run the full pipeline: distributed scan → consensus → federated refinement
just site      # preview the GitHub Pages site locally
```

`just pilot` drives a scientific workload through all five layers at once:

```
🌳 Orchard pilot — distributed folding scan
  scorer placement:  solo (scorer fits on one device)
  candidates:        12 evaluated across 4 nodes
  consensus:         12/12 (dissents rejected: 9)
  best conformation: [0.486, 0.336, 0.543]  energy 0.4708
  refined (federated DP gradient step):
                     [0.487, 0.208, 0.593]  energy 0.3009
  → energy reduced by 0.1699 toward the native state [0.500, -0.300, 0.800]
```

`just demo` on an OS 26+ machine produces a real on-device structured summary:

```json
{
  "title": "Apple Neural Engine Accelerates On-Device ML",
  "summary": "The Apple Neural Engine enhances machine learning directly on devices…",
  "topics": ["Apple", "Neural Engine", "On-Device ML", "Machine Learning"]
}
```

Requires macOS 26+ / Xcode 26+ for the on-device Foundation Models APIs. See [`TOOLS.md`](./TOOLS.md).

## Repository layout

```
orchard/
├── DESIGN.md                    # Architecture & system design
├── TOOLS.md                     # Toolchain, frameworks, dependencies
├── AGENTS.md                    # Guidance for AI coding agents
├── CLAUDE.md                    # Claude Code working agreement
├── justfile                     # Task runner
├── Package.swift                # SwiftPM manifest
├── Sources/
│   ├── OrchardProtocol/         # Wire types, task specs, schemas, node capabilities
│   ├── OrchardNode/             # Node runtime, scheduler, Foundation Models adapter
│   ├── OrchardSwarm/            # Peer discovery, coordinator election, layer-shard planner
│   ├── OrchardRouter/           # Job fragmentation, redundant assignment, consensus aggregation
│   ├── OrchardCrypto/           # Secure Aggregation (SecAgg) + differential privacy
│   ├── OrchardPilot/            # Capstone: one scientific workload through every layer
│   ├── OrchardMLX/              # Metal-accelerated ShardExecutor on mlx-swift (opt-in)
│   ├── OrchardTransport/        # Cross-device transport over TCP + Bonjour auto-discovery
│   ├── orchard-demo/            # Node + swarm + router + crypto + transport demo executable
│   ├── orchard-pilot/           # End-to-end folding-scan pilot executable
│   └── orchard-mlx-demo/        # MLX sharded-execution demo (opt-in, Metal)
├── Tests/                       # Swift Testing suites
├── docs/                        # GitHub Pages site
└── .github/                     # CI + Pages workflows
```

## License

[MIT](./LICENSE) — concept and scaffolding. Not affiliated with or endorsed by Apple Inc.
