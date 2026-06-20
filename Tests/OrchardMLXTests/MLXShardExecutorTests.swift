#if canImport(MLX)
    import MLX
    @testable import OrchardMLX
    import OrchardProtocol
    @testable import OrchardSwarm
    import Testing

    /// These run only when OrchardMLX is enabled (ORCHARD_ENABLE_MLX=1) on a Metal-capable machine.
    struct MLXShardExecutorTests {
        private let model = ShardableModel.deterministic(dimension: 16, layerCount: 8, seed: 11)
        private let input = [Float](repeating: 0.05, count: 16)

        @Test("MLX executor matches the pure-Swift oracle within float tolerance")
        func matchesLocalExecutor() async throws {
            let mlx = try await MLXShardExecutor(stream: .cpu).execute(layerRange: 0 ..< 8, of: model, input: input)
            let local = try await LocalShardExecutor().execute(layerRange: 0 ..< 8, of: model, input: input)
            #expect(mlx.count == local.count)
            let maxDiff = zip(mlx, local).map { abs($0 - $1) }.max() ?? 0
            #expect(maxDiff < 1e-3)
        }

        @Test("A sharded MLX pipeline equals running every layer at once")
        func shardedMatchesWhole() async throws {
            let plan = ShardPlan(modelName: "m", stages: [
                LayerShard(owner: NodeID("a"), layerRange: 0 ..< 5),
                LayerShard(owner: NodeID("b"), layerRange: 5 ..< 8),
            ])
            let executors: [NodeID: any ShardExecutor] = [
                NodeID("a"): MLXShardExecutor(stream: .cpu),
                NodeID("b"): MLXShardExecutor(stream: .cpu),
            ]
            let sharded = try await PipelineRunner().run(plan: plan, model: model, input: input, executors: executors)
            let whole = try await MLXShardExecutor(stream: .cpu).execute(layerRange: 0 ..< 8, of: model, input: input)
            let maxDiff = zip(sharded, whole).map { abs($0 - $1) }.max() ?? 0
            #expect(maxDiff < 1e-5)
        }

        @Test("Dimension mismatch is rejected")
        func dimensionMismatchThrows() async {
            await #expect(throws: ShardExecutorError.dimensionMismatch(expected: 16, actual: 2)) {
                try await MLXShardExecutor(stream: .cpu).execute(layerRange: 0 ..< 1, of: model, input: [0, 0])
            }
        }
    }
#endif
