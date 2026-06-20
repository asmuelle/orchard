import OrchardProtocol
@testable import OrchardSwarm
import Testing

struct SwarmCoordinatorTests {
    private func node(
        _ id: String,
        memoryMB: Double,
        tier: DeviceTier = .phone,
        power: Bool = true
    ) -> NodeCapabilities {
        NodeCapabilities(
            nodeID: NodeID(id),
            tier: tier,
            usableMemoryMB: memoryMB,
            aneGeneration: 18,
            isOnPower: power
        )
    }

    @Test("Runs solo when the local device can hold the model alone")
    func soloWhenLocalIsEnough() async {
        let local = node("iphone", memoryMB: 8000)
        let coordinator = SwarmCoordinator(
            local: local,
            discovery: StaticPeerDiscovery([]),
            planner: ShardPlanner(memoryHeadroom: 0)
        )
        let model = ModelProfile(name: "small", layerCount: 10, bytesPerLayerMB: 100) // 1000MB
        let formation = await coordinator.formSwarm(for: model)
        #expect(formation == .soloSufficient(NodeID("iphone")))
    }

    @Test("Forms a swarm and elects the Mac when the model is too big for the phone")
    func formsSwarmAcrossDevices() async {
        let local = node("iphone", memoryMB: 4000)
        let mac = node("mac", memoryMB: 32000, tier: .desktop)
        let coordinator = SwarmCoordinator(
            local: local,
            discovery: StaticPeerDiscovery([mac]),
            planner: ShardPlanner(memoryHeadroom: 0)
        )
        let model = ModelProfile(name: "big", layerCount: 100, bytesPerLayerMB: 100) // 10_000MB

        let formation = await coordinator.formSwarm(for: model)
        guard case let .swarm(coordinatorID, plan) = formation else {
            Issue.record("expected a swarm formation, got \(formation)")
            return
        }
        #expect(coordinatorID == NodeID("mac"))
        #expect(plan.coveredLayers == 100)
        // Mac (largest memory) leads the pipeline.
        #expect(plan.stages.first?.owner == NodeID("mac"))
    }

    @Test("Reports insufficient memory when even the swarm cannot hold the model")
    func insufficientAcrossSwarm() async {
        let local = node("iphone", memoryMB: 4000)
        let ipad = node("ipad", memoryMB: 4000, tier: .tablet)
        let coordinator = SwarmCoordinator(
            local: local,
            discovery: StaticPeerDiscovery([ipad]),
            planner: ShardPlanner(memoryHeadroom: 0)
        )
        let model = ModelProfile(name: "huge", layerCount: 100, bytesPerLayerMB: 100) // 10_000MB

        let formation = await coordinator.formSwarm(for: model)
        #expect(formation == .insufficient(requiredMB: 10000, availableMB: 8000))
    }
}
