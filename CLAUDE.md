# CLAUDE.md — Working agreement for Claude Code on Orchard

This file is loaded into context each session. It tells you how to work effectively in this
repository. For the architecture, read [`DESIGN.md`](./DESIGN.md); for the stack, [`TOOLS.md`](./TOOLS.md).

## What Orchard is

A decentralized, privacy-preserving swarm-intelligence platform that coordinates idle Apple
devices (iPhone/iPad/Mac) to run batchable AI workloads on-device via the Foundation Models
framework, while keeping raw user data local. It is currently a **concept skeleton** — most
runtime code does not exist yet. Build it out milestone by milestone (see `DESIGN.md` §9).

## Golden rules

1. **Privacy is the product.** Never write code that moves raw user data off-device. Only
   masked / differentially-private aggregates may cross the network. If a change weakens this,
   stop and flag it.
2. **Batch, not real-time.** Orchard targets asynchronous, resumable, checkpointed work.
   Don't design for low-latency conversational inference — the network can't support it.
3. **Opportunistic by default.** Heavy work runs only when a device is plugged in, on Wi-Fi,
   and idle. Respect the scheduler gate; never bypass it for convenience.
4. **Untrusted nodes.** Treat all node-returned results as adversarial. Validate, assign
   redundantly, and reach consensus before trusting output.

## How to work here

- **Plan before large changes.** For anything spanning multiple packages, sketch the approach
  first and confirm direction.
- **Small, focused files** (200–400 lines typical, 800 max). Organize by feature/package, not
  by type. New code matches the style of surrounding code.
- **Immutability first** — return new values, don't mutate in place.
- **TDD** — write the failing test, make it pass, refactor. Target 80%+ coverage on logic.
- **Validate at boundaries** — every wire message checked against `OrchardProtocol` schemas.
- **Use `just`** for everything: `just build`, `just test`, `just lint`, `just ci`. Don't invent
  parallel ad-hoc commands when a recipe exists.

## Project structure

```
packages/
  OrchardProtocol/   shared wire types, task specs, structured-output schemas
  OrchardNode/       node runtime, opportunistic scheduler, AFM adapter
  OrchardSwarm/      LAN discovery, layer sharding, swarm coordinator
  OrchardCrypto/     SecAgg, differential privacy, attestation
  OrchardRouter/     task fragmentation, cohort selection, consensus (PCC-side)
docs/                GitHub Pages site
.github/             CI + Pages workflows
```

## Before you finish

- `just ci` is green (build + test + lint + format check).
- No raw user data leaves the device in any new path.
- New behavior is covered by tests.
- Public docs (`DESIGN.md` / `TOOLS.md` / `docs/`) updated if architecture changed.

## Commits

Conventional commits (`feat:`, `fix:`, `refactor:`, `docs:`, `test:`, `chore:`). Commit or push
only when asked. Branch before committing if on the default branch.

## Apple framework reference

When working with the Foundation Models framework, on-device LLM, `@Generable` structured
output, or tool calling, consult the `foundation-models-on-device` skill and Apple's primary
docs rather than guessing API shapes — these APIs are new (iOS/macOS 26).
