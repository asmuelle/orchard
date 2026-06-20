@testable import OrchardPilot
import OrchardProtocol
import Testing

struct PilotTests {
    private let nodes = [NodeID("a"), NodeID("b"), NodeID("c")]

    @Test("Evaluates every candidate and reaches consensus on each")
    func evaluatesAllCandidatesByConsensus() async throws {
        let pilot = Pilot(config: PilotConfig(candidateCount: 8, redundancy: 3))
        let report = try await pilot.run(nodes: nodes)

        #expect(report.candidatesEvaluated == 8)
        #expect(report.consensusAchieved == 8)
        #expect(report.dissentsObserved == 0)
    }

    @Test("Federated refinement lowers the energy of the best conformation")
    func refinementImprovesEnergy() async throws {
        let pilot = Pilot(config: PilotConfig(candidateCount: 12, redundancy: 3))
        let report = try await pilot.run(nodes: nodes)
        #expect(report.refinedEnergy <= report.bestEnergy)
    }

    @Test("The scorer model is placed solo on a capable device")
    func scorerPlacedLocally() async throws {
        let pilot = Pilot(config: PilotConfig(candidateCount: 4))
        let report = try await pilot.run(nodes: nodes)
        #expect(report.swarmDecision.hasPrefix("solo"))
    }

    @Test("Consensus rejects a faulty node and still produces a result")
    func consensusFiltersFaultyNode() async throws {
        let fleet = [NodeID("a"), NodeID("b"), NodeID("c"), NodeID("d")]
        let pilot = Pilot(config: PilotConfig(candidateCount: 8, redundancy: 4))
        let report = try await pilot.run(nodes: fleet, faultyNodes: [NodeID("d")])

        // Redundancy 4 over 4 nodes ⇒ every task includes the faulty node ⇒ one dissent each.
        #expect(report.dissentsObserved == 8)
        #expect(report.consensusAchieved == 8)
        #expect(report.bestEnergy >= 0)
    }

    @Test("Deterministic across runs with the same seed")
    func deterministicForSameSeed() async throws {
        let pilot = Pilot(config: PilotConfig(candidateCount: 6, seed: 99))
        let first = try await pilot.run(nodes: nodes)
        let second = try await pilot.run(nodes: nodes)
        #expect(first.bestTheta == second.bestTheta)
        #expect(first.refinedTheta == second.refinedTheta)
    }
}
