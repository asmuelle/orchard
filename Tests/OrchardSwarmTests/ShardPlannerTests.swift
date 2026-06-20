import OrchardProtocol
@testable import OrchardSwarm
import Testing

struct ShardPlannerTests {
    /// No headroom keeps the arithmetic exact and assertions obvious.
    let planner = ShardPlanner(memoryHeadroom: 0)

    private func peer(_ id: String, memoryMB: Double, power: Bool = true) -> NodeCapabilities {
        NodeCapabilities(
            nodeID: NodeID(id),
            tier: .phone,
            usableMemoryMB: memoryMB,
            aneGeneration: 18,
            isOnPower: power
        )
    }

    @Test("Shards layers across peers, largest-memory peer first")
    func shardsAcrossPeers() throws {
        let model = ModelProfile(name: "m", layerCount: 10, bytesPerLayerMB: 100)
        let peers = [
            peer("small", memoryMB: 300), // fits 3 layers
            peer("big", memoryMB: 700), // fits 7 layers
        ]
        let plan = try planner.plan(model: model, across: peers)

        #expect(plan.coveredLayers == 10)
        #expect(plan.stages.count == 2)
        // "big" is ordered first and takes layers 0..<7, "small" takes 7..<10.
        #expect(plan.stages[0] == LayerShard(owner: NodeID("big"), layerRange: 0 ..< 7))
        #expect(plan.stages[1] == LayerShard(owner: NodeID("small"), layerRange: 7 ..< 10))
    }

    @Test("A single sufficient peer takes the whole model")
    func singlePeerTakesAll() throws {
        let model = ModelProfile(name: "m", layerCount: 4, bytesPerLayerMB: 50)
        let plan = try planner.plan(model: model, across: [peer("solo", memoryMB: 1000)])
        #expect(plan.stages == [LayerShard(owner: NodeID("solo"), layerRange: 0 ..< 4)])
    }

    @Test("Peers too small to hold even one layer are skipped")
    func skipsPeersThatCannotHoldALayer() throws {
        let model = ModelProfile(name: "m", layerCount: 2, bytesPerLayerMB: 100)
        let peers = [
            peer("tiny", memoryMB: 40), // fits 0 layers
            peer("ok", memoryMB: 500), // fits 5
        ]
        let plan = try planner.plan(model: model, across: peers)
        #expect(plan.stages.count == 1)
        #expect(plan.stages[0].owner == NodeID("ok"))
    }

    @Test("Throws when combined memory is insufficient")
    func throwsWhenInsufficient() {
        let model = ModelProfile(name: "m", layerCount: 10, bytesPerLayerMB: 100)
        #expect(throws: SwarmError.insufficientMemory(requiredMB: 1000, availableMB: 300)) {
            try planner.plan(model: model, across: [peer("a", memoryMB: 300)])
        }
    }

    @Test("Rejects an empty peer set and an invalid model")
    func rejectsBadInput() {
        let model = ModelProfile(name: "m", layerCount: 4, bytesPerLayerMB: 50)
        #expect(throws: SwarmError.noPeers) {
            try planner.plan(model: model, across: [])
        }
        #expect(throws: SwarmError.invalidModel) {
            try planner.plan(
                model: ModelProfile(name: "bad", layerCount: 0, bytesPerLayerMB: 50),
                across: [peer("a", memoryMB: 500)]
            )
        }
    }

    @Test("Headroom reduces the layers a peer accepts")
    func headroomReducesCapacity() throws {
        let withHeadroom = ShardPlanner(memoryHeadroom: 0.5)
        let model = ModelProfile(name: "m", layerCount: 5, bytesPerLayerMB: 100)
        // 1000MB * (1 - 0.5) = 500MB budget → 5 layers exactly.
        let plan = try withHeadroom.plan(model: model, across: [peer("a", memoryMB: 1000)])
        #expect(plan.coveredLayers == 5)
    }
}
