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

🚧 **Concept / skeleton.** This repository is an architecture blueprint and scaffolding. No
production node runtime ships yet. See the [roadmap](./DESIGN.md#roadmap).

## Quick start

```bash
just setup     # install toolchain + resolve packages
just build     # build all targets
just test      # run the test suite
just site      # preview the GitHub Pages site locally
```

Requires macOS 26+ / Xcode 26+ for the on-device Foundation Models APIs. See [`TOOLS.md`](./TOOLS.md).

## Repository layout

```
orchard/
├── DESIGN.md          # Architecture & system design
├── TOOLS.md           # Toolchain, frameworks, dependencies
├── AGENTS.md          # Guidance for AI coding agents
├── CLAUDE.md          # Claude Code working agreement
├── justfile           # Task runner
├── docs/              # GitHub Pages site
├── packages/          # Swift package targets (node, swarm, crypto, router)
└── .github/           # CI + Pages workflow
```

## License

[MIT](./LICENSE) — concept and scaffolding. Not affiliated with or endorsed by Apple Inc.
