#if canImport(Network)
    import Foundation
    import Network
    import OrchardProtocol

    // A peer found on the local network: its node id, advertised capabilities (from the Bonjour TXT
    // record), and a connectable endpoint. `RemoteShardExecutor(peer:)` turns one into a working
    // executor, so discovery feeds straight into the swarm pipeline.

    public struct DiscoveredPeer: Sendable {
        public let nodeID: NodeID
        public let capabilities: NodeCapabilities?
        let endpoint: NWEndpoint

        /// Manual / test construction via host:port.
        public init(
            nodeID: NodeID,
            capabilities: NodeCapabilities? = nil,
            host: String = "127.0.0.1",
            port: UInt16
        ) {
            self.nodeID = nodeID
            self.capabilities = capabilities
            endpoint = .hostPort(host: NWEndpoint.Host(host), port: NWEndpoint.Port(rawValue: port) ?? .any)
        }

        init(nodeID: NodeID, capabilities: NodeCapabilities?, endpoint: NWEndpoint) {
            self.nodeID = nodeID
            self.capabilities = capabilities
            self.endpoint = endpoint
        }
    }

    /// Browses the local network for peers. The real implementation is `BonjourBrowser`; tests and
    /// previews inject `StaticPeerBrowser`. Keeping it a protocol means the swarm wiring never depends
    /// on mDNS being available.
    public protocol PeerBrowser: Sendable {
        func discoverPeers(within duration: Duration) async -> [DiscoveredPeer]
    }

    public struct StaticPeerBrowser: PeerBrowser {
        public let peers: [DiscoveredPeer]

        public init(_ peers: [DiscoveredPeer]) {
            self.peers = peers
        }

        public func discoverPeers(within _: Duration) async -> [DiscoveredPeer] {
            peers
        }
    }
#endif
