import OrchardProtocol

// Elects the swarm coordinator: the device that fragments work, sequences the pipeline, and
// aggregates the result. The strongest, most stable device wins — most usable memory, then
// being on power, with a deterministic node-id tie-break so every peer elects the same leader
// without negotiation.

public enum CoordinatorElection {
    public static func elect(among peers: [NodeCapabilities]) -> NodeID? {
        peers.min(by: isStrongerCoordinator)?.nodeID
    }

    /// True when `lhs` is the better coordinator than `rhs` (sorts strongest-first).
    static func isStrongerCoordinator(_ lhs: NodeCapabilities, _ rhs: NodeCapabilities) -> Bool {
        if lhs.usableMemoryMB != rhs.usableMemoryMB {
            return lhs.usableMemoryMB > rhs.usableMemoryMB
        }
        if lhs.isOnPower != rhs.isOnPower {
            return lhs.isOnPower && !rhs.isOnPower
        }
        return lhs.nodeID.value < rhs.nodeID.value
    }
}
