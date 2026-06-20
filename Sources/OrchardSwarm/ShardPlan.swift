import OrchardProtocol

// The output of sharding: an ordered list of pipeline stages, each owning a contiguous range of
// the model's layers. Activations flow stage 0 → stage 1 → … across the LAN; weights stay put.

public struct LayerShard: Sendable, Hashable, Codable {
    public let owner: NodeID
    /// Half-open layer range [lowerBound, upperBound) this peer is responsible for.
    public let layerRange: Range<Int>

    public init(owner: NodeID, layerRange: Range<Int>) {
        self.owner = owner
        self.layerRange = layerRange
    }

    public var layerCount: Int {
        layerRange.count
    }
}

public struct ShardPlan: Sendable, Hashable, Codable {
    public let modelName: String
    /// Pipeline stages in execution order.
    public let stages: [LayerShard]

    public init(modelName: String, stages: [LayerShard]) {
        self.modelName = modelName
        self.stages = stages
    }

    public var peerCount: Int {
        stages.count
    }

    /// Total layers covered by the plan — should equal the model's layer count when complete.
    public var coveredLayers: Int {
        stages.reduce(0) { $0 + $1.layerCount }
    }
}
