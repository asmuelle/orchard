import OrchardProtocol
@testable import OrchardRouter
import Testing

struct AssignmentPlannerTests {
    private let planner = AssignmentPlanner()
    private let schema = StructuredSchema.required([("v", .string)])

    private func tasks(_ count: Int, redundancy: Int) throws -> [TaskSpec] {
        try (0 ..< count).map { i in
            try TaskSpec(
                id: TaskID("t\(i)"),
                kind: .infer,
                prompt: "p\(i)",
                outputSchema: schema,
                redundancy: redundancy
            )
        }
    }

    @Test("Assigns each task to `redundancy` distinct nodes")
    func assignsDistinctNodes() throws {
        let nodes = [NodeID("a"), NodeID("b"), NodeID("c")]
        let assignments = try planner.assign(tasks: tasks(1, redundancy: 2), to: nodes)
        #expect(assignments.count == 1)
        #expect(assignments[0].nodes.count == 2)
        #expect(Set(assignments[0].nodes).count == 2) // distinct
    }

    @Test("Caps redundancy at the number of available nodes")
    func capsRedundancy() throws {
        let nodes = [NodeID("a"), NodeID("b")]
        let assignments = try planner.assign(tasks: tasks(1, redundancy: 5), to: nodes)
        #expect(assignments[0].nodes.count == 2)
    }

    @Test("Balances load evenly across the fleet")
    func balancesLoad() throws {
        let nodes = [NodeID("a"), NodeID("b"), NodeID("c")]
        // 3 tasks × redundancy 1 = 3 assignments over 3 nodes → one each.
        let assignments = try planner.assign(tasks: tasks(3, redundancy: 1), to: nodes)
        let used = assignments.flatMap(\.nodes)
        #expect(Set(used).count == 3)
    }

    @Test("Throws when there are no nodes")
    func throwsWithoutNodes() throws {
        #expect(throws: RouterError.noNodes) {
            try planner.assign(tasks: tasks(1, redundancy: 1), to: [])
        }
    }
}
