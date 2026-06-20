import OrchardProtocol
@testable import OrchardRouter
import Testing

struct TaskRouterTests {
    private let schema = StructuredSchema.required([("topic", .string)])

    private func job(units: Int, redundancy: Int) -> Job {
        Job(
            id: "index",
            kind: .index,
            schema: schema,
            units: (0 ..< units).map { WorkUnit(id: "u\($0)", prompt: "summarize page \($0)") },
            redundancy: redundancy
        )
    }

    @Test("Resolves every task by consensus when honest nodes agree")
    func resolvesHonestFleet() async throws {
        let router = TaskRouter(dispatcher: AgreeingDispatcher())
        let nodes = [NodeID("a"), NodeID("b"), NodeID("c")]
        let outcome = try await router.run(job: job(units: 4, redundancy: 3), nodes: nodes)

        #expect(outcome.results.count == 4)
        #expect(outcome.agreedCount == 4)
        #expect(outcome.unresolvedCount == 0)
    }

    @Test("Outvotes and flags a single faulty node")
    func outvotesFaultyNode() async throws {
        let router = TaskRouter(dispatcher: FaultyNodeDispatcher(faulty: NodeID("c")))
        let nodes = [NodeID("a"), NodeID("b"), NodeID("c")]
        let outcome = try await router.run(job: job(units: 1, redundancy: 3), nodes: nodes)

        #expect(outcome.agreedCount == 1)
        let report = try #require(outcome.results.first)
        #expect(report.dissenters == [NodeID("c")])
    }

    @Test("Propagates a no-nodes error")
    func failsWithoutNodes() async {
        let router = TaskRouter(dispatcher: AgreeingDispatcher())
        await #expect(throws: RouterError.noNodes) {
            try await router.run(job: job(units: 1, redundancy: 2), nodes: [])
        }
    }
}

// MARK: - Test dispatchers

/// Every node returns the same payload derived from the task prompt — an honest, agreeing fleet.
private struct AgreeingDispatcher: NodeDispatcher {
    func dispatch(_ task: TaskSpec, to node: NodeID) async -> TaskResult {
        .completed(taskID: task.id, nodeID: node, payload: ["topic": .string(task.prompt)])
    }
}

/// One named node returns a divergent payload; the rest agree.
private struct FaultyNodeDispatcher: NodeDispatcher {
    let faulty: NodeID
    func dispatch(_ task: TaskSpec, to node: NodeID) async -> TaskResult {
        let value = node == faulty ? "⚠︎divergent" : task.prompt
        return .completed(taskID: task.id, nodeID: node, payload: ["topic": .string(value)])
    }
}
