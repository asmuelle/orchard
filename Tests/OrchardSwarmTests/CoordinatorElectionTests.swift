import OrchardProtocol
@testable import OrchardSwarm
import Testing

struct CoordinatorElectionTests {
    private func peer(
        _ id: String,
        memoryMB: Double,
        power: Bool = true,
        tier: DeviceTier = .phone
    ) -> NodeCapabilities {
        NodeCapabilities(
            nodeID: NodeID(id),
            tier: tier,
            usableMemoryMB: memoryMB,
            aneGeneration: 18,
            isOnPower: power
        )
    }

    @Test("Elects the peer with the most usable memory")
    func electsLargestMemory() {
        let elected = CoordinatorElection.elect(among: [
            peer("phone", memoryMB: 4000),
            peer("mac", memoryMB: 32000, tier: .desktop),
            peer("ipad", memoryMB: 8000, tier: .tablet),
        ])
        #expect(elected == NodeID("mac"))
    }

    @Test("Breaks a memory tie in favor of a powered device")
    func powerBreaksTie() {
        let elected = CoordinatorElection.elect(among: [
            peer("battery", memoryMB: 8000, power: false),
            peer("charging", memoryMB: 8000, power: true),
        ])
        #expect(elected == NodeID("charging"))
    }

    @Test("Breaks a full tie deterministically by node id")
    func nodeIdBreaksTie() {
        let elected = CoordinatorElection.elect(among: [
            peer("zeta", memoryMB: 8000),
            peer("alpha", memoryMB: 8000),
        ])
        #expect(elected == NodeID("alpha"))
    }

    @Test("Returns nil for an empty fleet")
    func emptyFleetHasNoCoordinator() {
        #expect(CoordinatorElection.elect(among: []) == nil)
    }
}
