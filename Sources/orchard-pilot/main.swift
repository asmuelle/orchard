import Foundation
import OrchardPilot
import OrchardProtocol

// End-to-end pilot: a folding-energy parameter scan driven through Swarm → Router → Node →
// consensus → Crypto. node-d is wired faulty to show consensus filtering bad results.

func format(_ values: [Double]) -> String {
    "[" + values.map { String(format: "%.3f", $0) }.joined(separator: ", ") + "]"
}

let nodes = [NodeID("node-a"), NodeID("node-b"), NodeID("node-c"), NodeID("node-d")]
let faulty: Set<NodeID> = [NodeID("node-d")]

let pilot = Pilot()

print("🌳 Orchard pilot — distributed folding scan")
do {
    let report = try await pilot.run(nodes: nodes, faultyNodes: faulty)
    print("  scorer placement:  \(report.swarmDecision)")
    print("  candidates:        \(report.candidatesEvaluated) evaluated across \(nodes.count) nodes")
    print("  consensus:         \(report.consensusAchieved)/\(report.candidatesEvaluated) (dissents rejected: \(report.dissentsObserved))")
    print("  best conformation: \(format(report.bestTheta))  energy \(String(format: "%.4f", report.bestEnergy))")
    print("  refined (federated DP gradient step):")
    print("                     \(format(report.refinedTheta))  energy \(String(format: "%.4f", report.refinedEnergy))")
    let drop = report.bestEnergy - report.refinedEnergy
    print("  → energy reduced by \(String(format: "%.4f", drop)) toward the native state \(format([0.5, -0.3, 0.8]))")
} catch {
    print("  pilot failed: \(error)")
}
