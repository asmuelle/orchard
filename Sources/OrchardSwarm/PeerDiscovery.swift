import OrchardProtocol

// Abstraction over local-network peer discovery. The production implementation advertises and
// browses over Bonjour / MultipeerConnectivity on the same Wi-Fi LAN; tests and the demo inject
// a fixed set. Keeping it a protocol means the coordinator never depends on the networking SDK.

public protocol PeerDiscovery: Sendable {
    /// Peers currently reachable on the local network, excluding the local device.
    func currentPeers() async -> [NodeCapabilities]
}

/// A fixed peer set for tests, previews, and the demo.
public struct StaticPeerDiscovery: PeerDiscovery {
    public let peers: [NodeCapabilities]

    public init(_ peers: [NodeCapabilities]) {
        self.peers = peers
    }

    public func currentPeers() async -> [NodeCapabilities] {
        peers
    }
}
