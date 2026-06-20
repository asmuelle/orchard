#if canImport(Network)
    import OrchardProtocol
    import OrchardSwarm
    @testable import OrchardTransport
    import Testing

    struct TransportTests {
        private let model = ShardableModel.deterministic(dimension: 8, layerCount: 6, seed: 5)
        private let input = [Float](repeating: 0.1, count: 8)

        private func approxEqual(_ a: [Float], _ b: [Float], tol: Float = 1e-5) -> Bool {
            a.count == b.count && zip(a, b).allSatisfy { abs($0 - $1) <= tol }
        }

        @Test("A shard executed over TCP matches local execution")
        func remoteExecutionMatchesLocal() async throws {
            let service = ShardService(executor: LocalShardExecutor(), model: model)
            let port = try await service.start()
            defer { Task { await service.stop() } }

            let remote = RemoteShardExecutor(endpoint: NodeEndpoint(port: port))
            let overTCP = try await remote.execute(layerRange: 0 ..< 6, of: model, input: input)
            let local = try await LocalShardExecutor().execute(layerRange: 0 ..< 6, of: model, input: input)

            #expect(approxEqual(overTCP, local))
        }

        @Test("A two-stage pipeline across two TCP services equals monolithic execution")
        func twoStagePipelineOverTCP() async throws {
            let stageA = ShardService(executor: LocalShardExecutor(), model: model)
            let stageB = ShardService(executor: LocalShardExecutor(), model: model)
            let portA = try await stageA.start()
            let portB = try await stageB.start()
            defer {
                Task { await stageA.stop() }
                Task { await stageB.stop() }
            }

            let plan = ShardPlan(modelName: "m", stages: [
                LayerShard(owner: NodeID("a"), layerRange: 0 ..< 4),
                LayerShard(owner: NodeID("b"), layerRange: 4 ..< 6),
            ])
            let executors: [NodeID: any ShardExecutor] = [
                NodeID("a"): RemoteShardExecutor(endpoint: NodeEndpoint(port: portA)),
                NodeID("b"): RemoteShardExecutor(endpoint: NodeEndpoint(port: portB)),
            ]

            let distributed = try await PipelineRunner().run(
                plan: plan, model: model, input: input, executors: executors
            )
            let monolithic = try await LocalShardExecutor().execute(
                layerRange: 0 ..< 6, of: model, input: input
            )
            #expect(approxEqual(distributed, monolithic))
        }

        @Test("A remote-side error propagates back to the caller")
        func remoteErrorPropagates() async throws {
            let service = ShardService(executor: LocalShardExecutor(), model: model)
            let port = try await service.start()
            defer { Task { await service.stop() } }

            let remote = RemoteShardExecutor(endpoint: NodeEndpoint(port: port))
            // Wrong input dimension → the server's executor throws → surfaced as a TransportError.remote.
            await #expect(throws: TransportError.self) {
                _ = try await remote.execute(layerRange: 0 ..< 1, of: model, input: [0, 0, 0])
            }
        }
    }
#endif
