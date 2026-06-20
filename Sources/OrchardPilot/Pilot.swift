import OrchardCrypto
import OrchardProtocol
import OrchardRouter
import OrchardSwarm

public enum PilotError: Error, Sendable, Hashable {
    case badCandidate(String)
    case noConsensus
}

public struct PilotConfig: Sendable {
    public var candidateCount: Int
    public var redundancy: Int
    public var refinementStep: Double
    public var dp: FederatedConfig
    public var seed: UInt64

    public init(
        candidateCount: Int = 12,
        redundancy: Int = 3,
        refinementStep: Double = 0.1,
        dp: FederatedConfig = FederatedConfig(clipNorm: 100, noiseSigma: 0, quantizationScale: 1_000_000),
        seed: UInt64 = 2026
    ) {
        self.candidateCount = candidateCount
        self.redundancy = redundancy
        self.refinementStep = refinementStep
        self.dp = dp
        self.seed = seed
    }
}

public struct PilotReport: Sendable {
    public let candidatesEvaluated: Int
    public let consensusAchieved: Int
    public let dissentsObserved: Int
    public let bestTheta: [Double]
    public let bestEnergy: Double
    public let refinedTheta: [Double]
    public let refinedEnergy: Double
    public let swarmDecision: String
}

/// The capstone: one scientific workload driven through every Orchard layer.
///   1. Swarm     — decide whether the scorer model fits locally or needs sharding.
///   2. Router    — fragment the search space into micro-tasks, assign redundantly, dispatch.
///   3. Node      — each task evaluates a conformation's energy via a real compute engine.
///   4. Consensus — agree per candidate; faulty nodes are outvoted and flagged.
///   5. Crypto    — refine the best conformation by a federated, privacy-preserving gradient step.
public struct Pilot: Sendable {
    private let config: PilotConfig

    public init(config: PilotConfig = PilotConfig()) {
        self.config = config
    }

    public func run(
        nodes: [NodeID],
        faultyNodes: Set<NodeID> = []
    ) async throws -> PilotReport {
        let candidates = makeCandidates()
        let swarmDecision = await decideScorerPlacement()

        // Router → Node → consensus.
        let job = Job(
            id: "fold",
            kind: .simulate,
            schema: StructuredSchema.required([("energy", .number)]),
            units: candidates.enumerated().map { index, theta in
                WorkUnit(id: "c\(index)", prompt: CandidateCodec.encode(theta))
            },
            redundancy: config.redundancy
        )
        let router = TaskRouter(dispatcher: PilotDispatcher(faulty: faultyNodes))
        let outcome = try await router.run(job: job, nodes: nodes)

        let (best, consensusAchieved, dissents) = try summarize(candidates: candidates, outcome: outcome)

        // Crypto: federated gradient refinement from the best conformation.
        let refined = refine(from: best.theta, honestNodes: nodes.filter { !faultyNodes.contains($0) })

        return PilotReport(
            candidatesEvaluated: candidates.count,
            consensusAchieved: consensusAchieved,
            dissentsObserved: dissents,
            bestTheta: best.theta,
            bestEnergy: best.energy,
            refinedTheta: refined,
            refinedEnergy: FoldingModel.energy(refined),
            swarmDecision: swarmDecision
        )
    }

    // MARK: - Steps

    private func makeCandidates() -> [[Double]] {
        var rng = SeededGenerator(seed: config.seed)
        let dimensions = FoldingModel.nativeState.count
        return (0 ..< config.candidateCount).map { _ in
            (0 ..< dimensions).map { _ in Double.random(in: -2 ... 2, using: &rng) }
        }
    }

    private func decideScorerPlacement() async -> String {
        let local = NodeCapabilities(
            nodeID: NodeID("pilot-local"),
            tier: .desktop,
            usableMemoryMB: 32000,
            aneGeneration: 18,
            isOnPower: true
        )
        let coordinator = SwarmCoordinator(local: local, discovery: StaticPeerDiscovery([]))
        let model = ModelProfile(name: "folding-scorer", layerCount: 4, bytesPerLayerMB: 50)
        switch await coordinator.formSwarm(for: model) {
        case .soloSufficient: return "solo (scorer fits on one device)"
        case let .swarm(coordinatorID, plan): return "swarm of \(plan.peerCount), coordinator \(coordinatorID)"
        case .insufficient: return "insufficient memory"
        }
    }

    private func summarize(
        candidates: [[Double]],
        outcome: JobOutcome
    ) throws -> (best: (theta: [Double], energy: Double), agreed: Int, dissents: Int) {
        var best: (theta: [Double], energy: Double)?
        var agreed = 0
        var dissents = 0

        for (theta, report) in zip(candidates, outcome.results) {
            dissents += report.dissenters.count
            guard case let .agreed(payload, _, _) = report.outcome,
                  case let .number(energy)? = payload["energy"]
            else { continue }
            agreed += 1
            if best == nil || energy < best!.energy {
                best = (theta, energy)
            }
        }

        guard let best else { throw PilotError.noConsensus }
        return (best, agreed, dissents)
    }

    private func refine(from theta: [Double], honestNodes: [NodeID]) -> [Double] {
        guard !honestNodes.isEmpty else { return theta }

        // Each honest node computes the gradient on its own slightly perturbed local copy —
        // modelling private local data. SecAgg + DP averages them without exposing any one.
        var rng = SeededGenerator(seed: config.seed &+ 99)
        let gradients = honestNodes.map { _ -> [Double] in
            let local = theta.map { $0 + Double.random(in: -0.05 ... 0.05, using: &rng) }
            return FoldingModel.gradient(at: local)
        }

        guard let meanGradient = try? FederatedRound.secureMean(
            gradients: gradients,
            config: config.dp,
            using: &rng
        ), meanGradient.count == theta.count else {
            return theta
        }

        return zip(theta, meanGradient).map { $0 - config.refinementStep * $1 }
    }
}
