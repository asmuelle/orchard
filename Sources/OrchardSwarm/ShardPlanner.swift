import OrchardProtocol

public enum SwarmError: Error, Sendable, Hashable {
    case noPeers
    case invalidModel
    /// The swarm's combined usable memory cannot hold the model.
    case insufficientMemory(requiredMB: Double, availableMB: Double)
}

// Partitions a model's layers across peers using pipeline parallelism. Greedy by design: order
// peers by usable memory (largest first, deterministic tie-break), then fill each peer with as
// many consecutive layers as its budget allows. The result is the minimal-hop assignment that
// fits — fewer, fatter stages mean fewer cross-device activation transfers, which matters most
// on bandwidth-limited consumer Wi-Fi.

public struct ShardPlanner: Sendable {
    /// Fraction of a peer's advertised memory held back for activations, KV cache, and OS overhead.
    public let memoryHeadroom: Double

    public init(memoryHeadroom: Double = 0.2) {
        self.memoryHeadroom = max(0, min(memoryHeadroom, 0.9))
    }

    public func plan(
        model: ModelProfile,
        across peers: [NodeCapabilities]
    ) throws(SwarmError) -> ShardPlan {
        guard model.layerCount > 0, model.bytesPerLayerMB > 0 else { throw .invalidModel }
        guard !peers.isEmpty else { throw .noPeers }

        let ordered = peers.sorted(by: Self.preferLargerMemory)

        var stages: [LayerShard] = []
        var nextLayer = 0
        for peer in ordered where nextLayer < model.layerCount {
            let budgetMB = peer.usableMemoryMB * (1 - memoryHeadroom)
            let fits = Int((budgetMB / model.bytesPerLayerMB).rounded(.down))
            guard fits > 0 else { continue }

            let upper = min(nextLayer + fits, model.layerCount)
            stages.append(LayerShard(owner: peer.nodeID, layerRange: nextLayer ..< upper))
            nextLayer = upper
        }

        guard nextLayer >= model.layerCount else {
            let availableMB = peers.reduce(0) { $0 + $1.usableMemoryMB * (1 - memoryHeadroom) }
            throw .insufficientMemory(requiredMB: model.totalMemoryMB, availableMB: availableMB)
        }

        return ShardPlan(modelName: model.name, stages: stages)
    }

    /// Deterministic ordering: more usable memory first, then powered devices, then node id.
    static func preferLargerMemory(_ lhs: NodeCapabilities, _ rhs: NodeCapabilities) -> Bool {
        if lhs.usableMemoryMB != rhs.usableMemoryMB {
            return lhs.usableMemoryMB > rhs.usableMemoryMB
        }
        if lhs.isOnPower != rhs.isOnPower {
            return lhs.isOnPower && !rhs.isOnPower
        }
        return lhs.nodeID.value < rhs.nodeID.value
    }
}
