import OrchardProtocol
@testable import OrchardSwarm
import Testing

struct PipelineRunnerTests {
    private let model = ShardableModel.deterministic(dimension: 8, layerCount: 12, seed: 7)
    private let input = [Float](repeating: 0.1, count: 8)

    private func peer(_ id: String, memoryMB: Double) -> NodeCapabilities {
        NodeCapabilities(nodeID: NodeID(id), tier: .phone, usableMemoryMB: memoryMB, aneGeneration: 18, isOnPower: true)
    }

    @Test("Sharded pipeline execution equals monolithic execution, bit for bit")
    func shardedMatchesMonolithic() async throws {
        // Plan splits the 12 layers across two devices…
        let planner = ShardPlanner(memoryHeadroom: 0)
        let bytesPerLayer = 100.0
        let profile = ModelProfile(name: "m", layerCount: 12, bytesPerLayerMB: bytesPerLayer)
        let plan = try planner.plan(
            model: profile,
            across: [peer("a", memoryMB: 700), peer("b", memoryMB: 700)] // 7 + 5 layers
        )
        #expect(plan.stages.count == 2)

        let executors: [NodeID: any ShardExecutor] = [
            NodeID("a"): LocalShardExecutor(),
            NodeID("b"): LocalShardExecutor(),
        ]
        let sharded = try await PipelineRunner().run(
            plan: plan, model: model, input: input, executors: executors
        )

        // …and the result matches running every layer on one device.
        let whole = try await LocalShardExecutor().execute(
            layerRange: 0 ..< model.layerCount, of: model, input: input
        )
        #expect(sharded == whole)
        #expect(sharded.count == model.dimension)
    }

    @Test("A missing executor for a stage owner is reported")
    func missingExecutorThrows() async throws {
        let plan = ShardPlan(modelName: "m", stages: [
            LayerShard(owner: NodeID("ghost"), layerRange: 0 ..< model.layerCount),
        ])
        await #expect(throws: PipelineRunner.RunError.missingExecutor(NodeID("ghost"))) {
            try await PipelineRunner().run(
                plan: plan, model: model, input: input, executors: [:]
            )
        }
    }

    @Test("A dimension mismatch in the input is rejected")
    func dimensionMismatchThrows() async {
        await #expect(throws: ShardExecutorError.dimensionMismatch(expected: 8, actual: 3)) {
            try await LocalShardExecutor().execute(
                layerRange: 0 ..< 1, of: model, input: [0, 0, 0]
            )
        }
    }
}
