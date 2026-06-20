import OrchardProtocol

// Abstraction over getting a task to a node and a result back. The production implementation
// sends the micro-prompt over the network (to a device's NodeRuntime, possibly via Private Cloud
// Compute relay) and awaits the structured reply; tests and the demo inject a local dispatcher.
// Keeping it a protocol means the router's fragmentation/assignment/consensus logic is pure and
// has no transport dependency.

public protocol NodeDispatcher: Sendable {
    func dispatch(_ task: TaskSpec, to node: NodeID) async -> TaskResult
}
