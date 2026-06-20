// Describes a model the swarm wants to run, in terms the planner reasons about: how many
// transformer layers it has and how much memory each costs. Pipeline-parallel sharding assigns
// contiguous layer ranges to peers, so per-layer cost is the unit that matters.

public struct ModelProfile: Sendable, Hashable, Codable {
    public let name: String
    public let layerCount: Int
    public let bytesPerLayerMB: Double

    public init(name: String, layerCount: Int, bytesPerLayerMB: Double) {
        self.name = name
        self.layerCount = layerCount
        self.bytesPerLayerMB = bytesPerLayerMB
    }

    /// Total resident memory the whole model requires, in MB.
    public var totalMemoryMB: Double {
        Double(layerCount) * bytesPerLayerMB
    }
}
