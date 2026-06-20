import OrchardProtocol

// Assigns each task to `redundancy` distinct nodes, balancing load across the fleet. Greedy
// least-loaded selection: for every task, pick the R currently-least-busy nodes (stable order on
// ties). This spreads work evenly and guarantees a task never lands on the same node twice, so
// redundant copies are genuinely independent and consensus is meaningful.

public struct Assignment: Sendable, Hashable {
    public let taskID: TaskID
    public let nodes: [NodeID]

    public init(taskID: TaskID, nodes: [NodeID]) {
        self.taskID = taskID
        self.nodes = nodes
    }
}

public struct AssignmentPlanner: Sendable {
    public init() {}

    public func assign(
        tasks: [TaskSpec],
        to nodes: [NodeID]
    ) throws(RouterError) -> [Assignment] {
        guard !nodes.isEmpty else { throw .noNodes }

        var load: [NodeID: Int] = nodes.reduce(into: [:]) { $0[$1] = 0 }
        var assignments: [Assignment] = []

        for task in tasks {
            let copies = min(task.redundancy, nodes.count)
            var chosen: [NodeID] = []
            var available = nodes

            for _ in 0 ..< copies {
                guard let pick = available.min(by: { load[$0, default: 0] < load[$1, default: 0] })
                else { break }
                chosen.append(pick)
                load[pick, default: 0] += 1
                available.removeAll { $0 == pick }
            }
            assignments.append(Assignment(taskID: task.id, nodes: chosen))
        }
        return assignments
    }
}
