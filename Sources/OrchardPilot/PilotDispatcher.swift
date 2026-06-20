import OrchardNode
import OrchardProtocol
import OrchardRouter

// Bridges the router to real node runtimes: each (task, node) pair runs through a NodeRuntime —
// exercising the opportunistic scheduler and engine exactly as a device would. Nodes named as
// faulty get the wrong-answer engine so the pilot can show consensus filtering them out.

public struct PilotDispatcher: NodeDispatcher {
    private let faulty: Set<NodeID>

    public init(faulty: Set<NodeID> = []) {
        self.faulty = faulty
    }

    public func dispatch(_ task: TaskSpec, to node: NodeID) async -> TaskResult {
        let engine: InferenceEngine = faulty.contains(node)
            ? FaultyFoldingEngine()
            : FoldingEngine()
        let runtime = NodeRuntime(
            nodeID: node,
            engine: engine,
            conditions: StaticConditionsProvider(.ready)
        )
        return await runtime.process(task)
    }
}
