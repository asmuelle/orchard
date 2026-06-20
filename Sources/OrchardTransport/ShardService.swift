#if canImport(Network)
    import Foundation
    import OrchardSwarm

    // The device-side service: listens for activation requests, runs the requested layer range through
    // its local ShardExecutor on its resident model shard, and returns the output activations. This is
    // what makes "weights stay put, activations flow" real — the model never crosses the wire.

    public actor ShardService {
        private let executor: any ShardExecutor
        private let model: ShardableModel
        private var listener: TCPListener?
        public private(set) var port: UInt16 = 0

        public init(executor: any ShardExecutor, model: ShardableModel) {
            self.executor = executor
            self.model = model
        }

        /// Starts listening on an OS-assigned port and returns it.
        public func start() async throws -> UInt16 {
            let listener = try TCPListener { channel in
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
