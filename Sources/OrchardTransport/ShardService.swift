#if canImport(Network)
    import Foundation
    import OrchardProtocol
    import OrchardSwarm

    // The device-side service: listens for activation requests, runs the requested layer range through
    // its local ShardExecutor on its resident model shard, and returns the output activations. This is
    // what makes "weights stay put, activations flow" real — the model never crosses the wire.

    public actor ShardService {
        private let executor: any ShardExecutor
        private let model: ShardableModel
        private let advertise: NodeCapabilities?
        private var listener: TCPListener?
        public private(set) var port: UInt16 = 0

        /// `advertiseAs` opts the service into Bonjour discovery, publishing the given capabilities
        /// in the service's TXT record. Omit it for a plain host:port service.
        public init(
            executor: any ShardExecutor,
            model: ShardableModel,
            advertiseAs capabilities: NodeCapabilities? = nil
        ) {
            self.executor = executor
            self.model = model
            advertise = capabilities
        }

        /// Starts listening on an OS-assigned port and returns it.
        public func start() async throws -> UInt16 {
            let advertisement = advertise.map {
                BonjourAdvertisement(name: $0.nodeID.value, txtRecord: CapabilityTXT.encode($0))
            }
            let listener = try TCPListener(advertise: advertisement) { channel in
                Task { await self.serve(channel) }
            }
            self.listener = listener
            let boundPort = try await listener.start()
            port = boundPort
            return boundPort
        }

        public func stop() {
            listener?.cancel()
            listener = nil
        }

        private func serve(_ channel: TCPChannel) async {
            do {
                try await channel.start()
                let request: ActivationRequest = try await WireFrame.read(from: channel)
                let output = try await executor.execute(
                    layerRange: request.layerRange,
                    of: model,
                    input: request.values
                )
                try await channel.send(WireFrame.encode(ActivationResponse(values: output, error: nil)))
            } catch {
                try? await channel.send(WireFrame.encode(ActivationResponse(values: nil, error: "\(error)")))
            }
            channel.close()
        }
    }
#endif
