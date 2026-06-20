#if canImport(Network)
    import Foundation
    import Network

    // Async wrapper over NWListener. Binds an OS-assigned TCP port and hands each inbound connection
    // to `onConnection` as a TCPChannel. `@unchecked Sendable`: NWListener isn't Sendable, but it's
    // confined to its dispatch queue and `self` is the only non-Sendable thing captured by handlers.

    struct BonjourAdvertisement {
        let name: String
        let txtRecord: NWTXTRecord
    }

    final class TCPListener: @unchecked Sendable {
        private let listener: NWListener
        private let advertisement: BonjourAdvertisement?
        private let queue = DispatchQueue(label: "orchard.transport.listener")
        private let onConnection: @Sendable (TCPChannel) -> Void

        init(
            advertise: BonjourAdvertisement? = nil,
            onConnection: @escaping @Sendable (TCPChannel) -> Void
        ) throws {
            listener = try NWListener(using: .tcp)
            advertisement = advertise
            self.onConnection = onConnection
        }

        /// Starts listening and returns the bound port once ready.
        func start() async throws -> UInt16 {
            if let advertisement {
                listener.service = NWListener.Service(
                    name: advertisement.name,
                    type: orchardServiceType,
                    txtRecord: advertisement.txtRecord
                )
            }
            listener.newConnectionHandler = { [onConnection] connection in
                onConnection(TCPChannel(connection: connection))
            }
            return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<UInt16, Error>) in
                let once = ResumeOnce(continuation)
                listener.stateUpdateHandler = { [self] state in
                    switch state {
                    case .ready: once.resume(returning: listener.port?.rawValue ?? 0)
                    case let .failed(error): once.resume(throwing: error)
                    case .cancelled: once.resume(throwing: TransportError.connectionClosed)
                    default: break
                    }
                }
                listener.start(queue: queue)
            }
        }

        func cancel() {
            listener.cancel()
        }
    }
#endif
