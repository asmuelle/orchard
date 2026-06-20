# AGENTS.md

Guidance for AI coding agents working in the Orchard repository. This follows the open
[AGENTS.md](https://agents.md) convention. Claude Code users: see also [`CLAUDE.md`](./CLAUDE.md),
which extends this with tool-specific workflow.

## Project snapshot

- **Orchard** — a decentralized, privacy-preserving swarm-intelligence platform that turns idle
  Apple devices into a cooperative compute network using on-device Foundation Models.
- **Stage:** concept skeleton. Architecture is in [`DESIGN.md`](./DESIGN.md); stack in
  [`TOOLS.md`](./TOOLS.md).
- **Languages:** Swift 6.1+ / SwiftPM. **Platforms:** iOS 26+, macOS 26+.

## Setup commands

```bash
just setup     # install/verify toolchain, resolve Swift packages
just build     # build all targets
just test      # run the test suite
just lint      # swiftlint
just format    # swiftformat (writes)
just ci        # full check (build + test + lint + format-check)
just site      # serve the docs/ GitHub Pages site locally
```

If `just` is unavailable: `brew install just`. See [`TOOLS.md`](./TOOLS.md) for the full toolchain.

## Non-negotiable constraints

1. **No raw user data leaves the device.** Only Secure-Aggregation-masked, differentially-private
   aggregates may be transmitted. Any change that violates this must be rejected.
2. **Asynchronous batch work only.** Do not introduce real-time/low-latency swarm-inference
   assumptions — consumer networks cannot support them.
3. **Opportunistic execution.** Heavy compute is gated on `plugged-in && Wi-Fi && idle`.
4. **Nodes are untrusted.** Validate, assign redundantly, and reach consensus on results.

## Code conventions

- Organize by feature/package; many small files (≤800 lines). High cohesion, low coupling.
- Prefer immutable values; avoid in-place mutation.
- Validate all external/wire input against `OrchardProtocol` schemas at the boundary.
- Handle errors explicitly; never silently swallow them.
- Naming: types/protocols `PascalCase`, functions/vars `camelCase`, constants `UPPER_SNAKE_CASE`.

## Testing

- TDD: write the failing test first, then implement, then refactor.
- Target ≥80% coverage on logic-bearing code.
- Tests must be deterministic and isolated. Mock network/peer transport; never depend on a live
  swarm in unit tests.
- Run `just test` (or `just ci`) before declaring work complete.

## Package map

| Package | Responsibility |
| --- | --- |
| `OrchardProtocol` | Shared wire types, task specs, structured-output schemas |
| `OrchardNode` | Node runtime, opportunistic scheduler, AFM inference adapter |
| `OrchardSwarm` | LAN discovery, layer sharding, pipeline-parallel coordinator |
| `OrchardCrypto` | SecAgg masking, differential privacy, attestation |
| `OrchardRouter` | Task fragmentation, cohort selection, consensus aggregation |

## Pull requests

- Keep diffs focused and scoped to one concern.
- Conventional-commit titles (`feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`).
- Ensure `just ci` passes. Update `DESIGN.md` / `TOOLS.md` when architecture or tooling changes.
- Call out explicitly in the PR body if a change touches the privacy or trust boundary.

## Security

- Never hardcode secrets; use Keychain or CI secrets.
- All transport over TLS. Audit any non-Apple dependency before adding it.
- For privacy/crypto-sensitive changes, request a focused security review.
