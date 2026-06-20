# Orchard — Architecture & System Design

**Status:** Draft / concept blueprint · **Last updated:** 2026-06-20

Orchard is a decentralized swarm-intelligence platform that coordinates idle Apple devices to
solve large computational problems while preserving user privacy by construction. This document
is the canonical reference for the system architecture, trust model, and roadmap.

---

## 1. Goals & non-goals

### Goals
- Run useful, batchable AI workloads on **idle, charging, Wi-Fi-connected** Apple devices.
- Keep **raw user data on-device** at all times. Only privacy-masked aggregates leave a device.
- Scale horizontally to millions of heterogeneous nodes with no central GPU spend.
- Degrade gracefully: any node can drop out mid-task without corrupting results.

### Non-goals
- **Real-time / low-latency inference.** Consumer Wi-Fi and cellular links cannot match
  NVLink. Orchard targets **asynchronous, batch-processed** work only.
- Sustained foreground compute. Background execution is bounded by OS policy (see §6).
- A cryptocurrency or token. Orchard is a compute commons, not a chain.

## 2. System overview

```
                         ┌──────────────────────────────┐
                         │        Task Router            │
                         │ (Apple Private Cloud Compute) │
                         │  • shards problem → micro-tasks│
                         │  • SecAgg coordinator          │
                         │  • consensus / aggregation     │
                         └───────────────┬───────────────┘
            micro-prompts ↓              │ masked gradients / structured results ↑
        ┌───────────────────────────────────────────────────────────────────┐
        │                          Edge Node Fleet                           │
        │   ┌────────────┐   ┌────────────┐            ┌────────────┐         │
        │   │  iPhone    │   │   iPad     │   ......    │   Mac      │         │
        │   │  AFM/ANE   │   │  AFM/ANE   │            │ AFM/ANE+GPU │         │
        │   └─────┬──────┘   └─────┬──────┘            └─────┬──────┘         │
        │         └──── Local Micro-Swarm (MLX, LAN P2P) ────┘                │
        └───────────────────────────────────────────────────────────────────┘
```

## 3. The four pillars

### 3.1 Local node execution
- Each device hosts a **Node Runtime** that interfaces with the Foundation Models framework
  for on-device inference on the Neural Engine.
- **Opportunistic scheduler** gates all heavy work behind three conditions, re-evaluated
  continuously: `isPluggedIn && isOnWiFi && isIdle` (typically overnight).
- Work is checkpointed so an interrupted task resumes or is reassigned, never lost.

### 3.2 Local micro-swarms
- Devices on the same high-speed LAN form a **micro-swarm** to run models larger than any one
  device's RAM, sharding neural-network layers across unified memories (MLX-style P2P, à la
  Exo / Infer-Ring).
- A swarm elects a **coordinator** (highest sustained RAM + power, usually the Mac). Pipeline
  parallelism across layer shards; activation tensors cross the LAN, not the model weights.

### 3.3 Global agentic workflows
- The Task Router fragments a massive problem into thousands of **micro-prompts**.
- Edge agents use AFM **structured output** and **tool calling** to process their chunk and
  return typed results.
- **Synthesized consensus:** millions of structured outputs are merged into large, accurate
  data maps or deep simulation runs. Redundant assignment + voting guards against bad nodes.

### 3.4 Cryptographic, privacy-first architecture
- **Federated Learning** with **Secure Aggregation (SecAgg):** devices train locally on
  encrypted local data; only pairwise-masked gradient updates are transmitted. The server can
  sum updates but cannot read any individual contribution.
- **Differential Privacy:** calibrated noise added to updates bounds what any aggregate can
  reveal about one user.
- Net effect: individual user data is **mathematically impractical to reconstruct**.

## 4. Trust & threat model

| Actor | Assumed capability | Mitigation |
| --- | --- | --- |
| Malicious node | Returns wrong results, drops out | Redundant assignment + majority voting; reputation scoring |
| Curious router | Wants to read user data | SecAgg masking + DP noise; router only sees masked sums |
| Network observer | Sniffs traffic | TLS + on-device encryption; only masked aggregates on the wire |
| Sybil attacker | Spins up fake nodes | Device attestation (DeviceCheck / App Attest), rate limits |

## 5. Data flow (federated training round)

1. Router selects a cohort and broadcasts the current global model + task spec.
2. Each node trains locally on its private data; computes a gradient/weight delta.
3. Node applies DP noise, then SecAgg pairwise masks; uploads the masked delta.
4. Router sums masked deltas — masks cancel — yielding an aggregate update, no individual visible.
5. Router updates the global model; repeat until convergence.

## 6. Constraints & bottlenecks (designed-around, not wished-away)

- **Bandwidth / latency:** moving weights or activations over consumer links is the dominant
  cost. → Asynchronous batch tasks; ship prompts/gradients, not weights, across the WAN.
- **iOS background limits:** the OS throttles sustained background compute to protect thermals
  and battery. → Require the charging/idle "sleep" state; use background-task budgets; chunk
  work into resumable units.
- **Memory ceilings on iOS:** smaller RAM than Mac. → Micro-swarm sharding; assign model size
  to the swarm's *combined* memory, not any single device.
- **Heterogeneity:** ANE generations differ. → Capability handshake; route task size to node tier.

## 7. Applications

- **Decentralized scientific research** — molecular folding, climate sims on idle Apple silicon.
- **Decentralized search & knowledge graph** — local agents read/summarize/index public web
  data into a collectively owned semantic database.
- **Collaborative creativity** — distribute frame-by-frame diffusion for cinematic AI video.

## 8. Component map

| Package | Responsibility |
| --- | --- |
| `OrchardNode` | Node runtime, opportunistic scheduler, AFM inference adapter |
| `OrchardSwarm` | LAN discovery, layer sharding, pipeline-parallel coordinator |
| `OrchardCrypto` | SecAgg masking, differential privacy, attestation |
| `OrchardRouter` | Task fragmentation, cohort selection, consensus aggregation (PCC-side) |
| `OrchardProtocol` | Shared wire types, task specs, structured-output schemas |

See [`TOOLS.md`](./TOOLS.md) for the concrete frameworks behind each.

## 9. Roadmap

- [x] **M0 — Skeleton** (this repo): docs, package layout, CI, Pages.
- [x] **M1 — Single-node runtime**: opportunistic scheduler + AFM structured-output task.
      Packages `OrchardProtocol` + `OrchardNode`, a `NodeRuntime` actor gating work behind the
      opportunistic scheduler, a Foundation Models adapter (real on-device inference on OS 26+)
      with a deterministic stub fallback, and the `orchard-demo` executable. Run `just demo`.
- [x] **M2 — Micro-swarm** (coordination layer): `OrchardSwarm` with `PeerDiscovery` (Bonjour
      abstraction), `CoordinatorElection`, a memory-aware pipeline-parallel `ShardPlanner`, and a
      `SwarmCoordinator` actor that picks solo-vs-swarm and emits a layer-shard plan. Real MLX
      tensor execution over Network.framework plugs in behind a future `ShardExecutor`.
- [x] **M3 — Global tasks**: `OrchardRouter` with `TaskFragmenter` (Job → micro-tasks),
      load-balancing `AssignmentPlanner` (redundant, distinct nodes), a `NodeDispatcher`
      abstraction, a majority-vote `ConsensusEngine` (quorum + dissenter detection), and a
      `TaskRouter` actor that fans tasks out concurrently and merges results into per-task consensus.
- [ ] **M4 — Privacy layer**: SecAgg + DP on a federated training round.
- [ ] **M5 — Pilot**: one real scientific workload end-to-end.

## 10. Open questions

- Incentive model for participation without becoming a token/chain.
- Verifiable computation: can we prove a node ran the assigned work honestly?
- Cohort fairness across device tiers and geographies.
- Energy accounting: net-carbon claims vs. real device draw.
