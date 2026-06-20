// The capability handshake a node advertises when joining a micro-swarm. Heterogeneous devices
// differ in memory and Neural Engine generation, so the swarm sizes work to a peer's real budget
// rather than assuming a uniform fleet.

public enum DeviceTier: String, Sendable, Hashable, Codable {
    case phone
    case tablet
    case desktop
}

public struct NodeCapabilities: Sendable, Hashable, Codable, Identifiable {
    public let nodeID: NodeID
    public let tier: DeviceTier
    /// Memory this device is willing to lend to swarm work, in MB.
    public let usableMemoryMB: Double
    /// Apple Neural Engine generation (higher is newer/faster). Used to route task size to tier.
    public let aneGeneration: Int
    public let isOnPower: Bool

    public var id: NodeID {
        nodeID
    }

    public init(
        nodeID: NodeID,
        tier: DeviceTier,
        usableMemoryMB: Double,
        aneGeneration: Int,
        isOnPower: Bool
    ) {
        self.nodeID = nodeID
        self.tier = tier
        self.usableMemoryMB = max(0, usableMemoryMB)
        self.aneGeneration = aneGeneration
        self.isOnPower = isOnPower
    }
}
