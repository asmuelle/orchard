#if canImport(Network)
    import Network
    import OrchardSwarm

    // A ShardExecutor whose "compute" is a network round-trip to a peer's ShardService. Because it
    // conforms to ShardExecutor, PipelineRunner drives a multi-device pipeline with zero changes —
    // a stage owned by a remote node simply gets one of these instead of a LocalShardExecutor.
    //
    // The `model` argument is intentionally ignored: the remote peer already holds its shard's
    // weights, so only the layer range and input activations travel over the wire.

    public struct RemoteShardExecutor: ShardExecutor {
        private let endpoint: NWEndpoint

        /// Targets a fixed host:port.
        public init(endpoint: NodeEndpoint) {
            self.endpoint = .hostPort(
                host: NWEndpoint.Host(endpoint.host),
                port: NWEndpoint.Port(rawValue: endpoint.port) ?? .any
            )
        }

        /// Targets a peer discovered over Bonjour (connects to its resolved service endpoint).
        public init(peer: DiscoveredPeer) {
            endpoint = peer.endpoint
        }

        public func execute(
            layerRange: Range<Int>,
            of _: ShardableModel,
            input: [Float]
        ) async throws -> [Float] {
            let channel = TCPChannel(endpoint: endpoint)
            try await channel.start()
            defer { channel.close() }

            try await channel.send(WireFrame.encode(ActivationRequest(layerRange: layerRange, values: input)))
            let response: ActivationResponse = try await WireFrame.read(from: channel)

            if let error = response.error {
                throw TransportError.remote(error)
            }
            guard let values = response.values else {
                throw TransportError.malformedResponse
            }
            return values
        }
    }
#endif
